-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_GuildDA_SrchGuildApplicationsList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_guildda_srchguildapplicationslist(_guild_id TEXT, _view_count INTEGER, _top_count INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select top(_view_count) t1.delete_type, t1.delete_complete_date, t1.delete_date, t1.org_server, t1.cur_server, COALESCE(t1.login_server, t1.org_server) login_server

					, t1.char_id, t1.user_id, t1.account_id, t1.account_name, t1.race, t1.class, t1.gender, t1.lev, t1.world, convert(nvarchar,t1.last_logout_time,20 ) last_logout_time,

					case WHEN last_login_time = last_logout_time and last_login_time != '1970-01-01 00:00:00.000' and last_logout_time > '2007-12-12 00:00:00.000' THEN '#339900'

						 WHEN last_login_time != last_logout_time or last_login_time = '1970-01-01 00:00:00.000'  THEN 'brown'

						 WHEN last_login_time = last_logout_time and last_login_time != '1970-01-01 00:00:00.000' THEN 'black'

						 end as logonoff

					, t2.applicant_intro, t2.apply_time

			from	user_data t1(nolock) LEFT JOIN user_guild_join_application t2(nolock) on t1.char_id = t2.char_id

			where	t2.guild_id=_guild_id and t2.char_id not in (select top(_top_count) char_id from user_guild_join_application(nolock) where guild_id=_guild_id order by char_id asc) order by t2.char_id asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_guildda_srchguildapplicationslist;
-- +goose StatementEnd
