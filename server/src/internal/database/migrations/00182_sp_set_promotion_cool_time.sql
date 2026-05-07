-- AionCore 5.8 — Sprint 1.1a batch 9 port: aion_SetPromotionCooltime_0724 (upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetPromotionCooltime_0724.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT promotion_id FROM user_promotion_cooltime(UPDLOCK)
--               WHERE char_id = @nCharId AND promotion_id = @nPromotionId)
--     UPDATE user_promotion_cooltime
--        SET last_promotion_time       = @nLastPromotionTime,
--            received_item_count       = @nReceivedItemCount,
--            cycle_received_item_count = @nCycleReceivedItemCount,
--            cycle_next_reset_time     = @nCycleNextResetTime
--      WHERE char_id = @nCharId AND promotion_id = @nPromotionId
--   ELSE
--     INSERT user_promotion_cooltime(...) VALUES (...)
--
-- Translation notes:
--   * Same canonical SQL Server 2000 upsert pattern as 00170 (SetMacro) /
--     00155 (ClientSettingsPut). PG `INSERT ... ON CONFLICT DO UPDATE` is
--     genuinely atomic — two concurrent claims on the same (char, promo)
--     are serialised at the index level, last-writer-wins, no race window.
--   * Composite PK (char_id, promotion_id) lives on user_promotion_cooltime
--     created in 00181 (GetPromotionCoolTimeList). Migration is order-
--     independent because 00182 only writes; if run before 00181 it would
--     fail to find the table — but goose enforces strict numeric ordering,
--     so 00181 always runs first.
--   * The 4 cooldown fields are all INTEGER (UNIX seconds / counts). The
--     cycle pair (cycle_received_item_count + cycle_next_reset_time) is a
--     sub-cycle for daily/weekly windows under the umbrella of the longer
--     promotion run; see 00181 docstring for the full data model.
--   * Returns rows-affected (always 1 for a successful upsert) so the
--     caller can sanity-check the round-trip — matches 00170 / 00155 /
--     00179 convention.
--
-- Used by:
--   scripts/handlers/cm_promotion_claim.lua  -- after granting a reward
--   scripts/lib/promotion.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpromotioncooltime(INTEGER, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpromotioncooltime(
    _char_id                  INTEGER,
    _promotion_id             SMALLINT,
    _last_promotion_time      INTEGER,
    _received_item_count      INTEGER,
    _cycle_received_count     INTEGER,
    _cycle_next_reset_time    INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    INSERT INTO user_promotion_cooltime(
        char_id, promotion_id,
        last_promotion_time, received_item_count,
        cycle_received_item_count, cycle_next_reset_time
    ) VALUES (
        _char_id, _promotion_id,
        _last_promotion_time, _received_item_count,
        _cycle_received_count, _cycle_next_reset_time
    )
    ON CONFLICT (char_id, promotion_id) DO UPDATE
       SET last_promotion_time       = EXCLUDED.last_promotion_time,
           received_item_count       = EXCLUDED.received_item_count,
           cycle_received_item_count = EXCLUDED.cycle_received_item_count,
           cycle_next_reset_time     = EXCLUDED.cycle_next_reset_time;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpromotioncooltime(INTEGER, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
