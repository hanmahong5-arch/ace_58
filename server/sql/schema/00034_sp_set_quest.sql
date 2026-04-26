-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_SetQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetQuest.sql
-- Updates an in-progress quest's status and progress fields. Companion of
-- aion_PutQuest (Round 5) which inserts the row.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setquest(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setquest(
    _user_id  INTEGER,
    _quest_id INTEGER,
    _status   INTEGER,   -- T-SQL tinyint, widened to int for client convenience
    _progress INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_quest
       SET quest_status   = _status,
           quest_progress = _progress
     WHERE char_id  = _user_id
       AND quest_id = _quest_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setquest(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
