-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetChallengeTaskContributorList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getchallengetaskcontributorlist(_task_db_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




   	SELECT contributor_id, contributor_name, score FROM challenge_task_contributor(nolock) Where challenge_task_id=_task_db_id order by score desc;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getchallengetaskcontributorlist;
-- +goose StatementEnd
