-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildMemberRankList_110705.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildmemberranklist_110705(_guild_id INTEGER, _type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DECLARE _utc_adjust BIGINT

	_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())

	

	if _type = 0		

	begin

		SELECT char_id, user_id, class, gender, lev, world, guild_rank, guild_intro, guild_nickname, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust) AS last_logout_time, a.race, 0, COALESCE(b.id, -1), COALESCE(permission,0) FROM user_data a left join house_instant b on a.char_id = b.id and b.state<>6 WHERE a.guild_id = _guild_id and a.delete_complete_date = 0 

	end

	else

	begin

		SELECT char_id, user_id, class, gender, lev, world, guild_rank, guild_intro, guild_nickname, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust) AS last_logout_time, a.race, b.id, b.addr_id, COALESCE(permission, 0) FROM user_data a, house_field b WHERE a.guild_id = _guild_id and a.delete_complete_date = 0 and a.char_id = b.owner_id AND b.owner_type = 2

	end

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildmemberranklist_110705;
-- +goose StatementEnd
