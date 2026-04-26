-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildJoinApplicantList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildjoinapplicantlist(_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT b.char_id, b.account_id, b.user_id, b.class, b.gender, b.lev, a.applicant_intro, a.apply_time

	FROM user_guild_join_application a WITH(NOLOCK)  RIGHT JOIN user_data b WITH(NOLOCK) on a.char_id = b.char_id

	WHERE a.guild_id = _guild_id and b.delete_complete_date = 0	

	


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildjoinapplicantlist;
-- +goose StatementEnd
