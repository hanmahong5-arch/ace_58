-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetChallengeTaskContributor.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setchallengetaskcontributor(_task_db_id BIGINT, _contributor_id INTEGER, _contributor_name TEXT, _score INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (Select challenge_task_id From challenge_task_contributor(updlock) Where challenge_task_id=_task_db_id and contributor_id=_contributor_id)

		Begin

			Update challenge_task_contributor Set score=_score

			Where challenge_task_id=_task_db_id and contributor_id = _contributor_id;

		End

	ELSE

		Begin

			Insert Into challenge_task_contributor(challenge_task_id, contributor_id, contributor_name, score)

			Values(_task_db_id, _contributor_id, _contributor_name, _score);

		End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchallengetaskcontributor;
-- +goose StatementEnd
