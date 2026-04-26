-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildJoinApplicantJoinInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildjoinapplicantjoininfo(_char_id INTEGER, _guild_id INTEGER, _type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DECLARE _utc_adjust BIGINT

	_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())

	

	if EXISTS (SELECT char_id FROM user_guild_join_application WHERE char_id = _char_id and guild_id = _guild_id)

	begin

		if _type = 0

		begin

			SELECT user_id, class, gender, lev, world, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust) AS last_logout_time, a.race, 0, COALESCE(b.id, -1), COALESCE(permission,0) FROM user_data a WITH(NOLOCK) left join house_instant b WITH(NOLOCK)  on a.char_id = b.id and b.state<>6 WHERE a.char_id = _char_id and a.guild_id = 0 and a.delete_complete_date = 0 

		end

		else if _type = 1

		begin

			SELECT user_id, class, gender, lev, world, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust) AS last_logout_time, a.race, b.id, b.addr_id, COALESCE(permission, 0) FROM user_data a WITH(NOLOCK), house_field b WITH(NOLOCK) WHERE a.char_id = _char_id and a.guild_id = 0 and a.delete_complete_date = 0 and a.char_id = b.owner_id AND b.owner_type = 2

		end

	end

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildjoinapplicantjoininfo;
-- +goose StatementEnd
