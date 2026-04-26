-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildName.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildname(_guild_name TEXT, _change_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	UPDATE Guild 

	SET name = _change_name, change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

	WHERE name = _guild_name




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildname;
-- +goose StatementEnd
