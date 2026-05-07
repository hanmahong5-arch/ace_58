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
--   * RETURNS VOID — caller cannot inspect insert outcome.
--   * NCSoft pvp_env had NO PK / NO UNIQUE, so duplicate (type,
--     normalised-pair) silently appended a fan-out row (consistent with
--     world_bot_channel_info, batch 11). Earlier draft TIGHTENED to PK
--     (type, entity_a, entity_b) + raised unique_violation on dup —
--     plan-critic correctly flagged this as a bug-for-bug regression
--     (callers were written assuming dup is OK). PIN: keep the PK we
--     added in 00249 (it gives O(log n) symmetric lookups for free),
--     but use ON CONFLICT DO NOTHING so the SP behaves as a silent
--     idempotent insert — equivalent to NCSoft's "dup-ok" semantics
--     when seen from caller's side. This is the strict bug-for-bug
--     restoration; callers do not need to call DeletePvPEnv first.
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
    -- ELSE branch — pinned. ON CONFLICT DO NOTHING restores NCSoft's
    -- silent-dup semantics on top of our PK (00249).
    IF (_entity_a < _entity_b) THEN
        INSERT INTO pvp_env (type, entity_a, entity_b)
        VALUES (_type, _entity_a, _entity_b)
        ON CONFLICT DO NOTHING;
    ELSE
        INSERT INTO pvp_env (type, entity_a, entity_b)
        VALUES (_type, _entity_b, _entity_a)
        ON CONFLICT DO NOTHING;
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpvpenv(SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd
