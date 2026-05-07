-- AionCore 5.8 — Sprint 1.1a batch 15 port: aion_ReplaceAbnormalStatus (buff/debuff UPSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ReplaceAbnormalStatus.sql
-- Original (T-SQL):
--   if EXISTS (SELECT char_id FROM user_abnormal_status(UPDLOCK)
--               WHERE char_id=@nCharId AND skill_id=@nSkillId)
--   begin
--       UPDATE user_abnormal_status SET ...all 11 fields...
--        WHERE char_id=@nCharId AND skill_id=@nSkillId
--   end else
--   begin
--       INSERT user_abnormal_status(char_id, skill_id, skill_level, target_slot,
--              effect_remain1..4, interval_value1..4)
--       VALUES (@nCharId, @nSkillId, @nSkillLevel, @nTargetSlot,
--               @nRemain1..4, @nIntervalValue1..4)
--   end
--
-- Translation notes:
--   * NCSoft sister of PutAbnormalStatus (00209). Schema delta is already
--     applied by 00209 (full column set added) — this migration only adds
--     the function. ON CONFLICT … DO UPDATE captures the IF EXISTS / UPDATE
--     / ELSE INSERT pattern atomically.
--   * Replace path INSERTs WITHOUT logout_time (T-SQL omits it). The DEFAULT 0
--     from 00209's ALTER fills the gap on insert; UPDATE branch leaves it
--     untouched. Bug-for-bug pin: replace flow does NOT bump logout_time —
--     only PutAbnormalStatus stamps a fresh logout instant. Game logic relies
--     on this: replace = "skill re-applied during play", logout_time stays at
--     the original suspend point.
--   * `target_slot` SMALLINT (T-SQL TINYINT). `skill_level` SMALLINT.
--     remain1..4 / interval1..4 are INTEGER.
--   * Returns rows-affected (1 for either branch — UPSERT always touches).
--
-- Bug-for-bug:
--   * No FK guard on char_id. Replace for a deleted char succeeds silently.
--   * UPDATE branch overwrites all 11 fields verbatim; partial updates require
--     callers to read-modify-write before invoking. T-SQL has the same shape.
--
-- Used by:
--   scripts/handlers/cm_skill_buff_replace.lua  (in-combat buff refresh)
--   scripts/lib/buff.lua

-- +goose Up
-- +goose StatementBegin
-- Schema invariant: 00209 already widened user_abnormal_status with the full
-- NCSoft column set. We need a UNIQUE on (char_id, skill_id) so ON CONFLICT
-- has a target. PK is (char_id, abnormal_id) and we set abnormal_id := skill_id
-- in PutAbnormalStatus, so the existing PK ALREADY covers the (char_id,
-- skill_id) lookup. We add an explicit named constraint anyway so the
-- ON CONFLICT clause reads with intent and does not depend on PK column
-- ordering aliasing.
-- ====================================================================
ALTER TABLE user_abnormal_status
    ADD CONSTRAINT user_abnormal_status_char_skill_uniq
    UNIQUE (char_id, skill_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_replaceabnormalstatus(
    INTEGER, INTEGER, SMALLINT, SMALLINT,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_replaceabnormalstatus(
    _char_id          INTEGER,
    _skill_id         INTEGER,
    _skill_level      SMALLINT,
    _target_slot      SMALLINT,
    _remain1          INTEGER,
    _remain2          INTEGER,
    _remain3          INTEGER,
    _remain4          INTEGER,
    _interval1        INTEGER,
    _interval2        INTEGER,
    _interval3        INTEGER,
    _interval4        INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Atomic UPSERT mirroring the IF EXISTS … UPDATE … ELSE INSERT pattern.
    -- abnormal_id := skill_id (R7 PK alignment, see 00209).
    -- logout_time NOT touched in either branch — bug-for-bug with NCSoft.
    INSERT INTO user_abnormal_status (
        char_id, abnormal_id,
        skill_id, skill_level, target_slot,
        effect_remain1, effect_remain2, effect_remain3, effect_remain4,
        interval_value1, interval_value2, interval_value3, interval_value4
    ) VALUES (
        _char_id, _skill_id,
        _skill_id, _skill_level, _target_slot,
        _remain1, _remain2, _remain3, _remain4,
        _interval1, _interval2, _interval3, _interval4
    )
    ON CONFLICT ON CONSTRAINT user_abnormal_status_char_skill_uniq DO UPDATE SET
        skill_level     = EXCLUDED.skill_level,
        target_slot     = EXCLUDED.target_slot,
        effect_remain1  = EXCLUDED.effect_remain1,
        effect_remain2  = EXCLUDED.effect_remain2,
        effect_remain3  = EXCLUDED.effect_remain3,
        effect_remain4  = EXCLUDED.effect_remain4,
        interval_value1 = EXCLUDED.interval_value1,
        interval_value2 = EXCLUDED.interval_value2,
        interval_value3 = EXCLUDED.interval_value3,
        interval_value4 = EXCLUDED.interval_value4;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_replaceabnormalstatus(
    INTEGER, INTEGER, SMALLINT, SMALLINT,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_abnormal_status
    DROP CONSTRAINT IF EXISTS user_abnormal_status_char_skill_uniq;
-- +goose StatementEnd
