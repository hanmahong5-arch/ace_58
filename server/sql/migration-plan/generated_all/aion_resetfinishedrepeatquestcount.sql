-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ResetFinishedRepeatQuestCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_resetfinishedrepeatquestcount(_user_id INTEGER, _quest_id INTEGER, _reset_num INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	UPDATE user_finished_quest with (updlock)

	SET repeat_quest_resetnum = _reset_num

	where  char_id = _user_id and  quest_id = _quest_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_resetfinishedrepeatquestcount;
-- +goose StatementEnd
