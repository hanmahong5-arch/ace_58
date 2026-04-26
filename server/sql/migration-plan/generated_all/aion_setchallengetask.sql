-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetChallengeTask.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setchallengetask()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
bigint,

	_status as tinyint,

	_complete_cnt as smallint,

	_last_complete_time as int

AS

BEGIN




    Update challenge_task 

	Set status=_status, complete_count=_complete_cnt, last_complete_time=_last_complete_time

	Where id=_task_db_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchallengetask;
-- +goose StatementEnd
