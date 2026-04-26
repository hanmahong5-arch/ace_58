-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putquest(_user_id INTEGER, _quest_id INTEGER, _quest_status INTEGER, _quest_progrss INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_quest(char_id, quest_id, quest_status, quest_progress)

VALUES (_user_id, _quest_id, _quest_status, _quest_progrss);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putquest;
-- +goose StatementEnd
