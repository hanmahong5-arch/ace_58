-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateFinishedQuestTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatefinishedquesttime(_user_id INTEGER, _quest_id INTEGER, _finished_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	UPDATE user_finished_quest

	SET quest_finishedtime = _finished_time

	WHERE char_id = _user_id AND quest_id = _quest_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatefinishedquesttime;
-- +goose StatementEnd
