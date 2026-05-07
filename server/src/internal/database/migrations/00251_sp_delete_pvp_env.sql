-- AionCore 5.8 — Sprint 1.1a batch 23 port: aion_DeletePvPEnv
-- (delete a pvp_env row regardless of (entity_a, entity_b) orientation).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeletePvPEnv.sql
-- Original (T-SQL):
--   DELETE pvp_env
--   WHERE (type=@nType and entity_a=@nEntityA and entity_b=@nEntityB)
--      or (type=@nType and entity_a=@nEntityB and entity_b=@nEntityA)
--
-- Schema:
--   `pvp_env` was created by 00249 (GetPvPEnv).
--
-- Translation notes:
--   * NCSoft's DELETE has an OR predicate covering BOTH orientations of
--     (a, b). This is defensive — even though PutPvPEnv normalises to
--     (min, max) on disk, the caller of DeletePvPEnv is not required to
--     know that and can supply args in either order. Pinned: keep the
--     OR predicate exactly as written.
--   * Returns INTEGER row-count (a strict widening of NCSoft's VOID
--     contract). Lua callers may ignore. This matches the convention
--     used by 00247 sp_remove_all_block which also widened to INTEGER.
--   * `tinyint` → SMALLINT (sister 00250 same rationale).
--
-- Bug-for-bug:
--   * If both orientations exist as rows on disk (only possible by
--     bypassing PutPvPEnv — direct INSERT), the OR predicate matches
--     BOTH and deletes both. Pinned (NCSoft semantics).
--   * Self-pair (a == b): the two halves of the OR collapse to the same
--     predicate; a single row matches and is deleted once. Pinned.
--   * No matching row → returns 0, no error. Pinned.
--
-- Used by:
--   scripts/handlers/gm_pvp_env_remove.lua   -- GM "unregister PvP pair"
--   scripts/lib/pvp_env.lua                  -- shared deleter

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepvpenv(SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _type      : enum slot (sister 00250)
-- _entity_a  : one side of the PvP pair (caller may supply in either order)
-- _entity_b  : other side
-- Returns INTEGER rows-affected (0 or 1 in normalised data; 2 only when
-- the table has been corrupted by direct INSERT bypassing PutPvPEnv).
CREATE OR REPLACE FUNCTION aion_deletepvpenv(
    _type     SMALLINT,
    _entity_a INTEGER,
    _entity_b INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    DELETE FROM pvp_env
     WHERE (type = _type AND entity_a = _entity_a AND entity_b = _entity_b)
        OR (type = _type AND entity_a = _entity_b AND entity_b = _entity_a);
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepvpenv(SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd
