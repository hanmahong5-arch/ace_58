-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteFinishedQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteFinishedQuest.sql
--
-- T-SQL body:
--   DELETE user_finished_quest WHERE char_id=@nUserId AND quest_id=@nQuestId
--
-- Removes ONE quest from the finished-quest log. Used by quest reset items
-- and by GM tools. Distinct from aion_DeleteAllQuest which wipes the entire
-- log (cascade context).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefinishedquest(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletefinishedquest(
    _user_id  INTEGER,
    _quest_id INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_finished_quest
     WHERE char_id  = _user_id
       AND quest_id = _quest_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefinishedquest(INTEGER, INTEGER);
-- +goose StatementEnd
