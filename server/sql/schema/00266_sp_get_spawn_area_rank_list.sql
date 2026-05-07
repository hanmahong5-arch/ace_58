-- AionCore 5.8 — Sprint 1.1a batch 26 port: aion_GetSpawnAreaRankList
-- (read full spawn_area_rank table — per-zone spawn-area ranking config).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetSpawnAreaRankList.sql
-- Original (T-SQL):
--   SET NOCOUNT ON
--   select world_no, spawn_area_name, rank from spawn_area_rank;
--   SET NOCOUNT OFF
--
-- Domain (NEW — not previously touched):
--   `spawn_area_rank` is a tiny world-config table NCSoft uses to assign a
--   tinyint rank (0..255) to a named spawn area within a world (zone).
--   The rank drives spawn density / mob tier inside that area. The table
--   is fully replicated to every world server at boot — this SP is the
--   read-side, with companion writers 00267 SetSpawnAreaRank (upsert) and
--   00268 DeleteSpawnAreaRank (single-key delete).
--
-- Schema (from NCSoft AionWorldLive._schema/tables.sql lines 771-775):
--   CREATE TABLE spawn_area_rank (
--       world_no         int          NOT NULL,
--       spawn_area_name  nvarchar(40) NOT NULL,
--       rank             tinyint      NOT NULL
--   );
--
--   * No PK in NCSoft (table is small and admin-driven). The companion
--     SetSpawnAreaRank uses the (world_no, spawn_area_name) tuple as the
--     update key — confirming it's the natural PK. We add it as a
--     PRIMARY KEY (strict tightening, matches the writer's contract).
--   * `rank` is reserved-ish in PG (window-function name); we therefore
--     access it bare in column position only — no double-quoting needed
--     because it's a regular identifier in column DDL and the writer
--     references it via positional INSERT.
--
-- Translation notes:
--   * SETOF return iterating rows — pgx Rows iterator pattern.
--   * Column order pinned: (world_no, spawn_area_name, rank).
--   * No WHERE / ORDER BY in NCSoft — we add neither.
--
-- Bug-for-bug:
--   * Empty table → 0 rows (no error). Pinned.
--   * Row order unspecified. Pinned (caller must not assume order).
--   * NCSoft used `nvarchar(40)`; we use VARCHAR(40). PG VARCHAR is UTF-8
--     by default (storage cost identical for ASCII; same logical width).
--     The 40-char limit is preserved.
--
-- Used by:
--   scripts/lib/spawn_area.lua             -- world boot loader
--   scripts/handlers/gm_spawn_reload.lua   -- GM hot-reload (Q3 entropy)

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- spawn_area_rank — first introduction. World-level config table mapping
-- (world, named area) → rank tier (1 byte). PK on the natural key added.
-- ====================================================================
CREATE TABLE IF NOT EXISTS spawn_area_rank (
    world_no         INTEGER     NOT NULL,
    spawn_area_name  VARCHAR(40) NOT NULL,
    rank             SMALLINT    NOT NULL,
    PRIMARY KEY (world_no, spawn_area_name)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getspawnarearanklist();
-- +goose StatementEnd

-- +goose StatementBegin
-- No parameters. Returns the entire spawn_area_rank table.
-- Column order pinned: (world_no, spawn_area_name, rank).
CREATE OR REPLACE FUNCTION aion_getspawnarearanklist()
RETURNS TABLE (
    world_no        INTEGER,
    spawn_area_name VARCHAR(40),
    rank            SMALLINT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT sar.world_no, sar.spawn_area_name, sar.rank FROM spawn_area_rank sar;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getspawnarearanklist();
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS spawn_area_rank;
-- +goose StatementEnd
