-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserBuddyDA_SrchMyBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userbuddyda_srchmybuddy(_char_id TEXT, _world_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	set ansi_warnings off

	

	select	0 is_what, t2.delete_date, t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.org_server, t2.cur_server, COALESCE(t2.login_server, t2.org_server) login_server, convert(nvarchar,t2.create_date,20 ) create_date, convert(char, t2.gender) gender, convert(char, t2.race) race, convert(char, t2.class) class, convert(char, t2.lev) lev, convert(char, t2.builder) builder, t2.world,

			case

				WHEN t2.last_login_time = t2.last_logout_time and t2.last_login_time != '1970-01-01 00:00:00.000' and t2.last_logout_time > '2007-12-12 00:00:00.000' THEN '#339900'

				WHEN t2.last_login_time != t2.last_logout_time or t2.last_login_time = '1970-01-01 00:00:00.000'  THEN 'brown'

				WHEN t2.last_login_time = t2.last_logout_time and t2.last_login_time != '1970-01-01 00:00:00.000' THEN 'black'

				end as logonoff

			, COALESCE(comment, '') as comment

	from	user_buddy1 t1(nolock), user_data t2(nolock)

	where	t1.char_id=_char_id and t2.org_server=_world_id 

	and		t1.buddy_id=t2.char_id

	union all					   

	select	1 is_what, t2.delete_date, t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.org_server, t2.cur_server, COALESCE(t2.login_server, t2.org_server) login_server, convert(nvarchar,t2.create_date,20 ) create_date, convert(char, t2.gender) gender, convert(char, t2.race) race, convert(char, t2.class) class, convert(char, t2.lev) lev, convert(char, t2.builder) builder, t2.world,

			case

				WHEN t2.last_login_time = t2.last_logout_time and t2.last_login_time != '1970-01-01 00:00:00.000' and t2.last_logout_time > '2007-12-12 00:00:00.000' THEN '#339900'

				WHEN t2.last_login_time != t2.last_logout_time or t2.last_login_time = '1970-01-01 00:00:00.000'  THEN 'brown'			  

				WHEN t2.last_login_time = t2.last_logout_time and t2.last_login_time != '1970-01-01 00:00:00.000' THEN 'black'

				end as logonoff

			, COALESCE(comment, '') as comment



	from	user_block t1(nolock), user_data t2(nolock)

	where	t1.char_id = _char_id and t2.org_server =_world_id

	and		t1.block_id=t2.char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userbuddyda_srchmybuddy;
-- +goose StatementEnd
