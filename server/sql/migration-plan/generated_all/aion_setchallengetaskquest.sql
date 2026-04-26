-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetChallengeTaskQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setchallengetaskquest(_task_db_id BIGINT, _quest_id INTEGER, _complete_cnt INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	Update challenge_task_quest Set complete_count=_complete_cnt

	Where challenge_task_id=_task_db_id and quest_id=_quest_id;



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchallengetaskquest;
-- +goose StatementEnd
