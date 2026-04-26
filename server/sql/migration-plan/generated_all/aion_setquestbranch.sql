-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetQuestBranch.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setquestbranch(_user_id INTEGER, _quest_id INTEGER, _quest_branch INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_quest

	SET quest_branch = _quest_branch

	WHERE char_id=_user_id and quest_id=_quest_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setquestbranch;
-- +goose StatementEnd
