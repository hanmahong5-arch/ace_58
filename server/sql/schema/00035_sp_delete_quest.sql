-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_DeleteQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteQuest.sql
-- Deletes one in-progress quest row. Used when quest is abandoned or replaced
-- by an event that wipes the chain (e.g. region transition).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletequest(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletequest(
    _user_id  INTEGER,
    _quest_id INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_quest
     WHERE char_id  = _user_id
       AND quest_id = _quest_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletequest(INTEGER, INTEGER);
-- +goose StatementEnd
