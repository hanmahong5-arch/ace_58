-- AionCore 5.8 — Sprint 1.1a batch 20 port: aion_SetFamiliarGrowthPoint
-- (focused single-column UPDATE: growth_point + update_time).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetFamiliarGrowthPoint.sql
-- Original (T-SQL):
--   UPDATE user_familiar
--   SET growth_point = @growthPoint, update_time = @updateTime
--   WHERE id = @dbId AND char_id = @masterId
--
-- Translation notes:
--   * Surgical update — only growth_point + update_time. Distinct from
--     aion_SetFamiliarInfo_20180226 (00235) which updates 9 columns at
--     once. NCSoft preserves both because the engine has hot-paths that
--     bump XP every kill (= this SP, minimum write set) and a "save
--     loadout" path that touches all of slots/looting/growth (= 00235).
--     Pinned: do not collapse the two; they serve different write
--     volumes and observability traces.
--   * Same `id AND char_id` ownership filter as 00124 / 00235 / 00238.
--     Defensive double-key WHERE — pinned.
--   * Silent no-op on missing row. Pinned.
--   * VOLATILE. RETURNS VOID. @updateTime is caller-supplied epoch-millis.
--
-- Bug-for-bug:
--   * NCSoft does not clamp / validate @growthPoint — negative growth
--     would persist. Pinned: caller-side validation is the only defence.
--   * No interaction with familiar level / evolve_cnt — the SP is purely
--     a write of the raw growth counter. Server-side level-up logic lives
--     in the Lua script that decides when to call SetFamiliarInfo to bump
--     evolve_cnt. Pinned.
--
-- Used by:
--   scripts/handlers/cm_familiar_xp_gain.lua   -- per-kill XP increment
--   scripts/lib/familiar.lua                   -- shared growth helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliargrowthpoint(BIGINT, INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _db_id         : user_familiar.id (BIGSERIAL PK)
-- _master_id     : owning char_id (defensive ownership filter)
-- _growth_point  : new XP / growth counter value (absolute, not delta)
-- _update_time   : caller epoch-millis
CREATE OR REPLACE FUNCTION aion_setfamiliargrowthpoint(
    _db_id        BIGINT,
    _master_id    INTEGER,
    _growth_point INTEGER,
    _update_time  BIGINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_familiar
       SET growth_point = _growth_point,
           update_time  = _update_time
     WHERE id      = _db_id
       AND char_id = _master_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliargrowthpoint(BIGINT, INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd
