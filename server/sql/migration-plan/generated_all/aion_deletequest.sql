-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletequest(_user_id INTEGER, _quest_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_quest

WHERE char_id=_user_id and quest_id=_quest_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletequest;
-- +goose StatementEnd
