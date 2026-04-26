-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetChallengeTaskList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getchallengetasklist(_union_id INTEGER, _type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




   	SELECT id, task_name_id, status, complete_count, last_complete_time FROM challenge_task(nolock) Where union_id=_union_id and type=_type;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getchallengetasklist;
-- +goose StatementEnd
