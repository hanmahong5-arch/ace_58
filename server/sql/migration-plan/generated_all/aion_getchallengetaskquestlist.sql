-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetChallengeTaskQuestList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getchallengetaskquestlist(_task_db_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




   	SELECT quest_id, complete_count FROM challenge_task_quest(nolock) Where challenge_task_id=_task_db_id;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getchallengetaskquestlist;
-- +goose StatementEnd
