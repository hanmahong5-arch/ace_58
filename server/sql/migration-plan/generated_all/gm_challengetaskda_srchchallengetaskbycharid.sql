-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ChallengeTaskDA_SrchChallengeTaskByCharId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_challengetaskda_srchchallengetaskbycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	t.id, union_id, task_name_id, type, status, complete_count, last_complete_time,	-- challenge_task

			contributor_id, contributor_name, score,	-- challenge_task_contributor

			case when type = 1 then g.name else null end as 'guild_name'

	FROM	challenge_task t

	JOIN	challenge_task_contributor c ON t.id = c.challenge_task_id

	LEFT JOIN	guild g ON g.id = union_id

	WHERE	contributor_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_challengetaskda_srchchallengetaskbycharid;
-- +goose StatementEnd
