-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_GetQuestList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetQuestList.sql
-- Loads all quest states for a char on enter-world, ordered by quest_id.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getquestlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getquestlist(_user_id INTEGER)
RETURNS TABLE (
    quest_id       INTEGER,
    quest_status   INTEGER,
    quest_progress INTEGER,
    quest_branch   INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT q.quest_id, q.quest_status, q.quest_progress, q.quest_branch
      FROM user_quest q
     WHERE q.char_id = _user_id
     ORDER BY q.quest_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getquestlist(INTEGER);
-- +goose StatementEnd
