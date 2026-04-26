-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutChallengeTaskQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putchallengetaskquest(_task_db_id BIGINT, _quest_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (Select challenge_task_id, quest_id From challenge_task_quest(nolock) Where challenge_task_id=_task_db_id and quest_id=_quest_id)

		Begin

			return 1;	-- 중복 도전 과제 퀘스트

		End

	ELSE

		Begin

			Insert Into challenge_task_quest(challenge_task_id, quest_id, complete_count)

				Values(_task_db_id, _quest_id, 0);



			IF @_e_r_r_o_r <> 0

				Begin

					return 2; -- insert 실패

				End

		End

	return 0;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchallengetaskquest;
-- +goose StatementEnd
