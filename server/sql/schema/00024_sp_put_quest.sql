-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_PutQuest.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutQuest.sql
-- T-SQL is a bare INSERT. We use INSERT...ON CONFLICT DO NOTHING because the
-- (char_id, quest_id) PK in our scaffold would cause a duplicate-key error,
-- and NCSoft's separate aion_SetQuest handles updates. Behaviorally identical
-- for first-write callers; safe-no-op for the duplicate case.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putquest(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putquest(
    _user_id  INTEGER,
    _quest_id INTEGER,
    _status   INTEGER,
    _progress INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_quest (char_id, quest_id, quest_status, quest_progress)
    VALUES (_user_id, _quest_id, _status, _progress)
    ON CONFLICT (char_id, quest_id) DO NOTHING;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putquest(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
