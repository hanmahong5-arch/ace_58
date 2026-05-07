-- AionCore 5.8 — Sprint 1.1a batch 15 port: aion_PutAbnormalStatus (buff/debuff INSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutAbnormalStatus.sql
-- Original (T-SQL):
--   INSERT user_abnormal_status(char_id, skill_id, skill_level, target_slot,
--          effect_remain1..4, interval_value1..4, logout_time)
--   VALUES (@nCharId, @nSkillId, @nSkillLevel, @nTargetSlot, @nRemain1..4,
--           @nIntervalValue1..4, dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0))
--
-- Schema delta:
--   Round 7 (00115) scaffolded user_abnormal_status with the bare minimum
--   columns the DeleteAllAbnormalStatus / DeleteAbnormalStatus pair touch:
--   (char_id, abnormal_id, remain_time_ms, casted_time, PK(char_id, abnormal_id)).
--   PutAbnormalStatus needs the full NCSoft surface — a single character can
--   have multiple buffs from the SAME skill (e.g. stacking shields on different
--   target_slot values) plus the per-effect interval_value tick state. We widen
--   additively (every new column NULLable / defaulted) so existing data and
--   the prior Delete SPs keep working untouched.
--
-- Translation notes:
--   * NCSoft column set: (char_id, skill_id, skill_level, target_slot,
--     effect_remain1..4, interval_value1..4, logout_time). The original PK
--     was effectively (char_id, skill_id) but for buffs that reuse the same
--     skill_id across stacks it relied on app-level dedup. We keep the R7 PK
--     (char_id, abnormal_id) for backward-compat — Put rows go in with
--     abnormal_id=skill_id (the simplest mapping the existing GetList consumers
--     expect).
--   * `target_slot` is TINYINT (0..255) in T-SQL → SMALLINT in PG (no TINYINT).
--   * `effect_remain1..4` and `interval_value1..4` are INT in T-SQL → INTEGER.
--   * `logout_time` is BIGINT in NCSoft (epoch seconds, set via
--     GetUnixtimeWithUTCAdjust(GetUTCDate(),0)). PG mirrors with BIGINT.
--   * Pure INSERT — no UPSERT. NCSoft has a sister proc ReplaceAbnormalStatus
--     (00210) for the upsert path; PutAbnormalStatus is the pure-insert variant
--     used when the caller has already verified absence (e.g. fresh login load
--     of persisted buffs from a save snapshot).
--   * Returns rows-affected (1 = inserted; 0 = collision on PK, which is
--     bug-for-bug the SQL Server behaviour where INSERT raises a PK error;
--     PG ON CONFLICT DO NOTHING returns 0 silently — we keep the simpler
--     direct INSERT and let the caller catch the unique_violation if it fires).
--
-- Bug-for-bug:
--   * No FK guard on char_id (NCSoft user_abnormal_status is freestanding).
--     A buff insert for a deleted char will succeed silently — matches T-SQL.
--   * No range guard on skill_id / skill_level — application layer must clamp.
--
-- Used by:
--   scripts/handlers/cm_save_abnormal_status.lua (logout buff snapshot)
--   scripts/lib/buff.lua

-- +goose Up
-- +goose StatementBegin
-- Additive widening: NCSoft full column set, all new columns defaulted so the
-- existing R7 rows + R10 DeleteAllAbnormalStatus stay valid.
ALTER TABLE user_abnormal_status
    ADD COLUMN IF NOT EXISTS skill_id          INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS skill_level       SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS target_slot       SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS effect_remain1    INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS effect_remain2    INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS effect_remain3    INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS effect_remain4    INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS interval_value1   INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS interval_value2   INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS interval_value3   INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS interval_value4   INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS logout_time       BIGINT   NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putabnormalstatus(
    INTEGER, INTEGER, SMALLINT, SMALLINT,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putabnormalstatus(
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
    -- Pure INSERT mirroring T-SQL. abnormal_id := skill_id keeps R7 PK happy
    -- (one row per (char_id, skill_id)); the ReplaceAbnormalStatus sister SP
    -- handles the upsert path explicitly when callers expect to overwrite.
    INSERT INTO user_abnormal_status (
        char_id, abnormal_id,
        skill_id, skill_level, target_slot,
        effect_remain1, effect_remain2, effect_remain3, effect_remain4,
        interval_value1, interval_value2, interval_value3, interval_value4,
        logout_time
    ) VALUES (
        _char_id, _skill_id,
        _skill_id, _skill_level, _target_slot,
        _remain1, _remain2, _remain3, _remain4,
        _interval1, _interval2, _interval3, _interval4,
        GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
    );
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putabnormalstatus(
    INTEGER, INTEGER, SMALLINT, SMALLINT,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_abnormal_status
    DROP COLUMN IF EXISTS logout_time,
    DROP COLUMN IF EXISTS interval_value4,
    DROP COLUMN IF EXISTS interval_value3,
    DROP COLUMN IF EXISTS interval_value2,
    DROP COLUMN IF EXISTS interval_value1,
    DROP COLUMN IF EXISTS effect_remain4,
    DROP COLUMN IF EXISTS effect_remain3,
    DROP COLUMN IF EXISTS effect_remain2,
    DROP COLUMN IF EXISTS effect_remain1,
    DROP COLUMN IF EXISTS target_slot,
    DROP COLUMN IF EXISTS skill_level,
    DROP COLUMN IF EXISTS skill_id;
-- +goose StatementEnd
