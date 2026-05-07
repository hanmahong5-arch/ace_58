-- AionCore 5.8 — Sprint 1.1a batch 23 port: aion_PutPvPEnv
-- (insert a pvp_env row, normalising (entity_a, entity_b) so a < b).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutPvPEnv.sql
-- Original (T-SQL):
--   if (@nEntityA < @nEntityB)
--     INSERT pvp_env(type, entity_a, entity_b) VALUES (@nType, @nEntityA, @nEntityB)
--   ELSE
--     INSERT pvp_env(type, entity_a, entity_b) VALUES (@nType, @nEntityB, @nEntityA)
--
-- Schema:
--   `pvp_env` was created by 00249 (sister SP `GetPvPEnv` in the same batch).
--   Composite PK (type, entity_a, entity_b) — NCSoft had no PK, we tighten.
--
-- Translation notes:
--   * The IF/ELSE branch is purely orientation-normalisation: NCSoft stores
--     the pair (entity_a, entity_b) ALWAYS with the smaller id first. This
--     makes downstream symmetry-free queries cheap. Pinned exactly as
--     written — equality (@nEntityA == @nEntityB) takes the ELSE branch
--     (smaller-or-equal goes second) which still produces a valid row,
--     entity_a == entity_b. NCSoft does not reject self-pair; we keep this
--     pin for bug-for-bug compatibility (gives caller-visible "entity X
--     PvP-engaged with itself" — useful for sentinel rows).
--   * `tinyint` (1 byte) in T-SQL → SMALLINT in PG (no TINYINT in PG;
--     SMALLINT is the strict superset). NCSoft never sends > 127.
--   * RETURNS VOID — caller cannot inspect insert outcome. Duplicate
--     (type, normalised-pair) raises a unique-violation; NCSoft did not
--     have a PK so it would silently dup. We tighten to fail-fast: if
--     callers want idempotency they should call DeletePvPEnv first.
--     This is the SAFER behaviour and matches the convention used by
--     aion_putfamiliar (00234) which also raises on dup.
--
-- Bug-for-bug:
--   * (entity_a == entity_b) self-pair: stored verbatim. Pinned.
--   * type is unconstrained (SMALLINT covers -32k..32k). NCSoft tinyint is
--     0..255 unsigned; PG SMALLINT is signed. Caller is trusted not to
--     pass negative values. Pinned (no clamp).
--   * No timestamp / audit column. NCSoft never recorded who/when. Pinned.
--
-- Used by:
--   scripts/handlers/gm_pvp_env_add.lua        -- GM "register PvP pair"
--   scripts/lib/pvp_env.lua                    -- shared writer

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpvpenv(SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _type      : enum slot (NCSoft tinyint → SMALLINT). 1 byte semantically.
-- _entity_a  : one side of the PvP pair (any int — legion / faction id)
-- _entity_b  : other side (any int)
-- The pair is normalised to (min, max) on disk so symmetric lookups
-- need not consider order.
CREATE OR REPLACE FUNCTION aion_putpvpenv(
    _type     SMALLINT,
    _entity_a INTEGER,
    _entity_b INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- NCSoft IF (a < b): keep order, else swap. (a == b) falls into the
    -- ELSE branch — pinned.
    IF (_entity_a < _entity_b) THEN
        INSERT INTO pvp_env (type, entity_a, entity_b)
        VALUES (_type, _entity_a, _entity_b);
    ELSE
        INSERT INTO pvp_env (type, entity_a, entity_b)
        VALUES (_type, _entity_b, _entity_a);
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpvpenv(SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd
