-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteAllQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllQuest.sql
--
-- T-SQL body wipes BOTH active and finished quests for a character — the
-- two DELETEs are intentionally in the same SP so the sweeper makes one
-- call instead of two:
--   DELETE FROM user_quest          WHERE char_id=@nCharId
--   DELETE FROM user_finished_quest WHERE char_id=@nCharId

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallquest(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteallquest(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_quest          WHERE char_id = _char_id;
    DELETE FROM user_finished_quest WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallquest(INTEGER);
-- +goose StatementEnd
