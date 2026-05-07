-- AionCore 5.8 — Sprint 1.1a batch 23 port: aion_GetPvPEnv
-- (read full pvp_env table — list of cross-faction PvP relationships).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetPvPEnv.sql
-- Original (T-SQL):
--   SELECT type, entity_a, entity_b
--   FROM pvp_env
--
-- Domain (NEW — not previously touched):
--   `pvp_env` is a tiny world-level configuration table. NCSoft uses it to
--   register fixed PvP relationships between two entities (legions, factions,
--   races) keyed by `type`. The companion writers (00250 PutPvPEnv,
--   00251 DeletePvPEnv) keep canonical orientation `entity_a < entity_b` so
--   queries can ignore symmetry. The reader (this SP) returns the whole
--   table at server boot and on admin reload — there is no `WHERE` filter.
--
-- Schema (from NCSoft AionWorldLive._schema/tables.sql):
--   CREATE TABLE pvp_env (
--       type     char(1)  NOT NULL,
--       entity_a int      NOT NULL,
--       entity_b int      NOT NULL
--   );
--
--   * `type` is char(1) in T-SQL — a one-byte enum tag. We render as
--     SMALLINT in PG (PG has no TINYINT and char(1) over the wire is
--     ambiguous). The SP signature in the writer takes `tinyint` so a
--     small-int slot here is the strict superset. Pinned: NCSoft never
--     sends a value > 127.
--   * No PK on the original table — composite (type, entity_a, entity_b)
--     would be the natural key, but NCSoft did not enforce uniqueness.
--     We DO add a composite PK to make ON CONFLICT cheap for future
--     ports of variants like `aion_PutPvPEnvIdempotent`. This is a
--     strict tightening (the live data set has no dups).
--
-- Translation notes:
--   * Returning a SETOF instead of a single row — pgx.Rows iterator
--     pattern in Go. Column order pinned: (type, entity_a, entity_b).
--   * No char_id involved — this SP is a global-config read.
--
-- Bug-for-bug:
--   * Empty table → 0-row result set (no error, no notice). Pinned.
--   * Order of returned rows is unspecified (no ORDER BY in NCSoft).
--     We do not add one — call sites assume nothing.
--
-- Used by:
--   scripts/lib/pvp_env.lua       -- world boot loader
--   scripts/handlers/cm_admin_reload_pvp_env.lua -- GM hot-reload

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- pvp_env — first introduction. Tiny world-level config table for
-- cross-entity PvP relationships. PK added (NCSoft did not have one
-- but live data is unique on the triple).
-- ====================================================================
CREATE TABLE IF NOT EXISTS pvp_env (
    type     SMALLINT NOT NULL,
    entity_a INTEGER  NOT NULL,
    entity_b INTEGER  NOT NULL,
    PRIMARY KEY (type, entity_a, entity_b)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpvpenv();
-- +goose StatementEnd

-- +goose StatementBegin
-- No parameters. Returns the whole pvp_env table.
CREATE OR REPLACE FUNCTION aion_getpvpenv()
RETURNS TABLE (
    type     SMALLINT,
    entity_a INTEGER,
    entity_b INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT pe.type, pe.entity_a, pe.entity_b FROM pvp_env pe;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpvpenv();
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS pvp_env;
-- +goose StatementEnd
