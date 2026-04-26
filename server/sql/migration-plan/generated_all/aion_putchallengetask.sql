-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutChallengeTask.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putchallengetask(_task_db_id BIGINT, _union_id INTEGER, _type INTEGER, _task_name_id INTEGER, _status INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (Select id From challenge_task(nolock) Where union_id=_union_id and type=_type and task_name_id=_task_name_id)

		Begin

			return 1;	-- 중복 도전 과제

		End

	ELSE

		Begin

			Insert Into challenge_task(union_id, type, task_name_id, status, complete_count, last_complete_time)

				Values(_union_id, _type, _task_name_id, _status, 0, 0);



			IF @_e_r_r_o_r <> 0

				Begin

					return 2; -- insert 실패	

				End

			

			_task_db_id := @_i_d_e_n_t_i_t_y

		End

	return 0;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchallengetask;
-- +goose StatementEnd
