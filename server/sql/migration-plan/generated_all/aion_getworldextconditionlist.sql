-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetWorldExtConditionList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getworldextconditionlist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	SELECT world_num, variable, value FROM world_extcondition WITH(NOLOCK) WHERE world_type = 0

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getworldextconditionlist;
-- +goose StatementEnd
