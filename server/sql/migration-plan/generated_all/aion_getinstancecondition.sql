-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetInstanceCondition.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstancecondition(_current_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT world_num, variable, value FROM world_extcondition WHERE world_type = 1 and world_num IN (SELECT instance_id FROM instance WHERE validity_time > _current_time)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstancecondition;
-- +goose StatementEnd
