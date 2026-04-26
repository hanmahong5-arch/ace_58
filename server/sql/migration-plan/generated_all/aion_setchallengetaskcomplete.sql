-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetChallengeTaskComplete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setchallengetaskcomplete()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
bigint,

	_status as tinyint,

	_complete_cnt as smallint,

	_last_complete_time as int,

	_repeat as tinyint

AS

BEGIN


	If _repeat=1

	Begin

		Update challenge_task 

			Set status=_status, complete_count=_complete_cnt, last_complete_time=_last_complete_time

			Where id=_task_db_id;

		Update challenge_task_quest

			Set complete_count=0 Where challenge_task_id=_task_db_id;

		Update challenge_task_contributor

			Set score=0 Where challenge_task_id=_task_db_id;

	End

	Else

	Begin

		Update challenge_task 

		Set status=_status, complete_count=_complete_cnt, last_complete_time=_last_complete_time

		Where id=_task_db_id;

	End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchallengetaskcomplete;
-- +goose StatementEnd
