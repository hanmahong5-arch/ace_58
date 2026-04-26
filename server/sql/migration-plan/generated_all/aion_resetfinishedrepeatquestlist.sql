-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ResetFinishedRepeatQuestList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_resetfinishedrepeatquestlist(_questlist TEXT, _user_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql


BEGIN


	

	declare _sql nvarchar(max)

		

	_sql := 'UPDATE user_finished_quest '

				+ 'SET repeat_quest_count = 0 '

				+ ' WHERE char_id = ' + cast(_user_id AS nvarchar(20))+' AND quest_id IN ( ' + _questlist + ')'



	exec sp_executesql _sql

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_resetfinishedrepeatquestlist;
-- +goose StatementEnd
