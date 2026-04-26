-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteChallengeTask.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletechallengetask()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
bigint

AS

BEGIN


	Delete From challenge_task Where id=_task_db_id;

	Delete From challenge_task_quest Where challenge_task_id=_task_db_id;

	Delete From challenge_task_contributor Where challenge_task_id=_task_db_id;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletechallengetask;
-- +goose StatementEnd
