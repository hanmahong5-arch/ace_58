-- AionCore 5.8 — Sprint 1.1a batch 26 port: aion_SetSpawnAreaRank
-- (upsert per (world_no, spawn_area_name) → rank tier).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetSpawnAreaRank.sql
-- Original (T-SQL):
--   if exists (select world_no from spawn_area_rank(UPDLOCK)
--              where world_no=@world_no and spawn_area_name=@spawn_area_name)
--     update spawn_area_rank set rank=@rank
--      where world_no=@world_no and spawn_area_name=@spawn_area_name
--   else
--     insert spawn_area_rank(world_no, spawn_area_name, rank)
--     values(@world_no, @spawn_area_name, @rank)
--
-- Schema:
--   `spawn_area_rank` was introduced by 00266 (sister GetSpawnAreaRankList).
--
-- Translation notes:
--   * NCSoft uses the EXISTS-with-UPDLOCK upsert pattern: the UPDLOCK hint
--     forces SQL Server to take an update lock on the row during the
--     EXISTS check so a concurrent writer cannot slip an INSERT in. PG's
--     ON CONFLICT DO UPDATE is *strictly tighter* (single atomic op);
--     observable result is identical.
--   * `tinyint` (1 byte) → SMALLINT (PG has no 1-byte int; SMALLINT is the
--     strict superset for unsigned 0..255 — pinned). NCSoft caller is
--     trusted not to pass values outside 0..255.
--   * `nvarchar(40)` → VARCHAR(40) (sister 00266 same rationale).
--   * RETURNS VOID — caller cannot inspect upsert outcome.
--
-- Bug-for-bug:
--   * (world_no, spawn_area_name) tuple pinned as the upsert key. Pinned.
--   * No timestamp / audit column. Pinned (NCSoft never tracked).
--   * spawn_area_name is case-sensitive in PG (CITEXT or LOWER() would
--     widen). NCSoft SQL Server collation determined sensitivity at the
--     DB level — typical Korean game DBs run case-INsensitive collation,
--     so two writes with different case on `spawn_area_name` would land
--     on the same row in NCSoft but on different rows in PG. **This is
--     a known divergence**: caller-side normalisation is the safer path
--     and matches every other migration's policy. Pinned (no CITEXT).
--
-- Used by:
--   scripts/handlers/gm_spawn_rank_set.lua  -- GM "set spawn area rank"
--   scripts/lib/spawn_area.lua               -- shared writer

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setspawnarearank(INTEGER, VARCHAR, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _world_no        : world (zone) id
-- _spawn_area_name : human-readable spawn area name (NCSoft nvarchar(40))
-- _rank            : tier 0..255 (NCSoft tinyint)
-- Upsert keyed on (world_no, spawn_area_name).
CREATE OR REPLACE FUNCTION aion_setspawnarearank(
    _world_no        INTEGER,
    _spawn_area_name VARCHAR(40),
    _rank            SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Single-statement atomic upsert. Replaces NCSoft's
    -- EXISTS(UPDLOCK)-then-UPDATE-or-INSERT with ON CONFLICT.
    INSERT INTO spawn_area_rank (world_no, spawn_area_name, rank)
    VALUES (_world_no, _spawn_area_name, _rank)
    ON CONFLICT (world_no, spawn_area_name) DO UPDATE
       SET rank = EXCLUDED.rank;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setspawnarearank(INTEGER, VARCHAR, SMALLINT);
-- +goose StatementEnd
