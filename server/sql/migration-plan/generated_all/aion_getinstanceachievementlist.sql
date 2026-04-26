-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetInstanceAchievementList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstanceachievementlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT world_id, spawn_page, version, data FROM user_instance_achievement WHERE char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstanceachievementlist;
-- +goose StatementEnd
