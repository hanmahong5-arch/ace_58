-- AionCore 5.8 — Sprint 1.1a batch 10 port: aion_DeleteAllOverseasEventQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllOverseasEventQuest.sql
-- Original (T-SQL):
--   DELETE FROM overseas_event_quest
--
-- Translation notes:
--   * Wholesale wipe of the overseas-event quest **whitelist** (no char_id,
--     no quest_id filter). Used by the GM tool when a new event cycle
--     begins: clear, re-seed, ship. 00186 (PutOverseasEventQuest) is the
--     re-seed SP.
--   * NOT a TRUNCATE — DELETE keeps PG sequence/WAL/bloat behaviour
--     identical to the SQL Server source, and lets the call return a
--     row-count. TRUNCATE would lose the row-count and behave very
--     differently under a transaction (no MVCC visibility for concurrent
--     readers). The whitelist is small (typically <100 rows); DELETE cost
--     is negligible.
--   * Table overseas_event_quest declared in 00186 with `IF NOT EXISTS`;
--     this migration is order-independent at the table level (goose
--     enforces 00186 < 00187 numerically anyway).
--   * Returns rows-affected for telemetry ("swept N rows before re-seed").
--     Matches the 00184 (DeleteAllPromotionCoolTime) convention.
--   * Function NOT declared STABLE — it mutates state.
--
-- Used by:
--   scripts/admin/overseas_event_reset.lua    -- GM tool: end an event cycle
--   scripts/lib/overseas_event.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletealloverseaseventquest();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletealloverseaseventquest()
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM overseas_event_quest;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletealloverseaseventquest();
-- +goose StatementEnd
