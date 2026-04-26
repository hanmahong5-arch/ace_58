-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetUserGuildJoinApplicationInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserguildjoinapplicationinfo(_char_i_d INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	-- Insert statements for procedure here

	SELECT COALESCE(b.id, 0) as guild_id, COALESCE(b.name, '') as guild_name

	FROM user_guild_join_application a WITH(NOLOCK) LEFT OUTER JOIN guild b WITH(NOLOCK) ON a.guild_id = b.id  

	WHERE a.char_id = _char_i_d




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserguildjoinapplicationinfo;
-- +goose StatementEnd
