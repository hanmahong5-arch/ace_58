-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ChallengeTaskDA_SrchChallengeTaskQuestByUnionId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_challengetaskda_srchchallengetaskquestbyunionid(_union_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	union_id,	-- challenge_task

			challenge_task_id, quest_id, q.complete_count	-- challenge_task_quest

	FROM	challenge_task t

	JOIN	challenge_task_quest q ON q.challenge_task_id = t.id

	WHERE	union_id = _union_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_challengetaskda_srchchallengetaskquestbyunionid;
-- +goose StatementEnd
