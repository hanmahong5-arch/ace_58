-- AionCore 5.8 — Sprint 1.1a batch 20 port: aion_SetFamiliarInfo_20180226
-- (bulk-update familiar slots + looting + growth in a single round-trip).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetFamiliarInfo_20180226.sql
-- Original (T-SQL):
--   UPDATE user_familiar
--   SET slot1 = @slot1, slot2 = @slot2, slot3 = @slot3,
--       slot4 = @slot4, slot5 = @slot5, slot6 = @slot6,
--       looting_state = @looting_state,
--       growth_point = @growth_point,
--       update_time = @update_time
--   WHERE id = @dbId AND char_id = @masterId
--
-- Translation notes:
--   * Versioned name suffix `_20180226` is the latest dated revision in
--     NCSoft's evolution chain. Earlier `aion_SetFamiliarInfo` (no date)
--     exists in the dump but is superseded — pinned to the dated version
--     per "newest wins" convention used elsewhere (e.g. aion_GetCharInfo
--     keeps `_20180521` in production). Function name in PG mirrors the
--     dated form so callers can cleanly opt into the contract.
--   * Both `id` and `char_id` are required in WHERE — defensive ownership
--     check identical to aion_DeleteFamiliar (00124). A familiar's slots
--     can only be rewritten by its owning master.
--   * Silent no-op on missing row (UPDATE … WHERE … not-found) — pinned
--     per NCSoft contract (no THROW, no return value).
--   * VOLATILE (data-modifying). No return value (RETURNS VOID).
--   * `looting_state` is TINYINT in T-SQL → SMALLINT in PG (pinned at the
--     00148 schema widening, no further mapping needed).
--
-- Bug-for-bug:
--   * NCSoft does NOT touch create_time, name, evolve_cnt, base_name_id,
--     cur_name_id, safety_flag — those have their own dedicated SPs
--     (SetFamiliarName / SetFamiliarSafetyFlag / etc.). Pinned: this is
--     the "battle loadout" update only.
--   * @update_time is caller-supplied epoch-millis (NOT server clock).
--     Two clients writing concurrently would race on this value with no
--     server-side reconciliation. Pinned: NCSoft never added an MVCC
--     compare-and-swap; last writer wins on update_time.
--
-- Used by:
--   scripts/handlers/cm_familiar_save.lua    -- save battle loadout (slots)
--   scripts/lib/familiar.lua                 -- shared mutation helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarinfo_20180226(BIGINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _db_id          : user_familiar.id (BIGSERIAL PK)
-- _master_id      : owning char_id (defensive ownership filter)
-- _slot1.._slot6  : 6 inventory slots (item ids; 0 == empty)
-- _looting_state  : 0/1 auto-loot toggle (TINYINT → SMALLINT)
-- _growth_point   : XP / growth resource counter
-- _update_time    : caller epoch-millis (NOT server clock — pinned)
CREATE OR REPLACE FUNCTION aion_setfamiliarinfo_20180226(
    _db_id         BIGINT,
    _master_id     INTEGER,
    _slot1         INTEGER,
    _slot2         INTEGER,
    _slot3         INTEGER,
    _slot4         INTEGER,
    _slot5         INTEGER,
    _slot6         INTEGER,
    _looting_state SMALLINT,
    _growth_point  INTEGER,
    _update_time   BIGINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_familiar
       SET slot1         = _slot1,
           slot2         = _slot2,
           slot3         = _slot3,
           slot4         = _slot4,
           slot5         = _slot5,
           slot6         = _slot6,
           looting_state = _looting_state,
           growth_point  = _growth_point,
           update_time   = _update_time
     WHERE id      = _db_id
       AND char_id = _master_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarinfo_20180226(BIGINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT, INTEGER, BIGINT);
-- +goose StatementEnd
