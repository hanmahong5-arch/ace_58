-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setquest(_user_id INTEGER, _quest_id INTEGER, _quest_status INTEGER, _quest_progres INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_quest

SET quest_status=_quest_status, quest_progress=_quest_progres

WHERE char_id=_user_id and quest_id=_quest_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setquest;
-- +goose StatementEnd
