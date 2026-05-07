-- AionCore 5.8 — Sprint 1.1a batch 10 port: aion_PutOverseasEventQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutOverseasEventQuest.sql
-- Original (T-SQL):
--   INSERT overseas_event_quest(quest_id) VALUES (@nQuestId)
--
-- Translation notes:
--   * `overseas_event_quest` is the **server-wide quest whitelist** — a flat
--     table (no char_id) that lists which quest_ids are eligible for the
--     "overseas event" promotion track at this point in time. Real shape
--     verified from NCSoft live dump: single-column row, single index on
--     quest_id, no per-player state.
--     Task-spec line "user_overseas_event_quest, 写入海外事件 quest 状态"
--     is a misread — the table is NCSoft's GM-driven *catalogue*, not a
--     player progress table. Player-side overseas-event progress is tracked
--     elsewhere (e.g. user_player_quest with a special quest_id range).
--   * Table created here as the first consumer in the SP catalogue; 00187
--     (DeleteAllOverseasEventQuest) wipes the same shape. Schema is
--     intentionally a single-column table mirroring T-SQL exactly — not
--     widened with metadata, because every existing producer / consumer
--     SP only touches quest_id.
--   * Plain INSERT, **no UPSERT** — the T-SQL source intentionally allows
--     duplicates (NCSoft's GM tool naively appends; the consumer DISTINCTs
--     on read). PG inherits the same bug-for-bug semantics; if a future
--     refactor wants idempotence, add a UNIQUE constraint and switch to
--     ON CONFLICT DO NOTHING here.
--   * Returns rows-affected (always 1 for a successful insert) so the
--     caller can sanity-check the round-trip. Replaces T-SQL VOID return.
--   * Function NOT declared STABLE — it mutates state.
--
-- Used by:
--   scripts/admin/overseas_event_seed.lua    -- GM tool: enable a quest
--   scripts/lib/overseas_event.lua

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS overseas_event_quest (
    quest_id INTEGER NOT NULL
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putoverseaseventquest(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putoverseaseventquest(
    _quest_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    INSERT INTO overseas_event_quest(quest_id) VALUES (_quest_id);
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putoverseaseventquest(INTEGER);
-- +goose StatementEnd
