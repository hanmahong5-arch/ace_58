-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutFinishedQuestEx_20130327.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putfinishedquestex_20130327(_user_id INTEGER, _quest_id INTEGER, _branch INTEGER, _finished_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT char_id FROM user_finished_quest(UPDLOCK) WHERE char_id = _user_id AND quest_id = _quest_id)

	BEGIN

		UPDATE user_finished_quest

		SET quest_count = quest_count + 1, repeat_quest_count = repeat_quest_count + 1, quest_branch = _branch, quest_finishedtime = _finished_time

		WHERE char_id = _user_id AND quest_id = _quest_id

	END

	ELSE

	BEGIN

		INSERT user_finished_quest (char_id, quest_id, quest_count, quest_branch, quest_finishedtime, repeat_quest_count)

		VALUES (_user_id, _quest_id, 1, _branch, _finished_time, 1)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfinishedquestex_20130327;
-- +goose StatementEnd
