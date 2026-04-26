-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ChallengeTaskDA_SrchChallengeTaskContributorByUnionId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_challengetaskda_srchchallengetaskcontributorbyunionid(_union_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


			set transaction isolation level read uncommitted



			SELECT	challenge_task_id, contributor_id, contributor_name, score	-- challenge_task_contributor

					,g.master_id, u.account_id

			FROM	challenge_task t (nolock)

			JOIN	challenge_task_contributor c (nolock) ON c.challenge_task_id = t.id

			LEFT JOIN guild g (nolock) ON g.id = c.contributor_id		-- guild

			LEFT JOIN user_data u (nolock) ON u.char_id = g.master_id	-- guild_master

			WHERE	t.union_id = _union_id




		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_challengetaskda_srchchallengetaskcontributorbyunionid;
-- +goose StatementEnd
