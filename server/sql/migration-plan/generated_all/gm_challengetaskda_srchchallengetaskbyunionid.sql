-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ChallengeTaskDA_SrchChallengeTaskByUnionId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_challengetaskda_srchchallengetaskbyunionid(_union_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	id, union_id, task_name_id, type, status, complete_count, last_complete_time

	FROM	challenge_task

	WHERE	union_id = _union_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_challengetaskda_srchchallengetaskbyunionid;
-- +goose StatementEnd
