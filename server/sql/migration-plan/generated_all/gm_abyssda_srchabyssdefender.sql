-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssDA_SrchAbyssDefender.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssdefender(_world_id TEXT, _abyss_id TEXT, _srch_type TEXT, _user_id TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted



			declare _sql nvarchar(4000), _sql_where nvarchar(200)



			_sql_where := ''

			IF (_user_id != 'null')

			BEGIN

				IF _srch_type = '1'

					_sql_where := _sql_where + ' and user_id = N'''+_user_id+''''

				ELSE

					_sql_where := _sql_where + ' and defender_rank = '''+_user_id+''''

			END



			_sql := 'select top('+_view_count+') ' +

						'		a.*,' +

						'		COALESCE(u.delete_type, 0) as delete_type, COALESCE(u.delete_complete_date, 0) as delete_complete_date, COALESCE(u.delete_date, 0) as delete_date, COALESCE(u.char_id, a.defender_char_id) as char_id, COALESCE(u.user_id, 0) as user_id,' +

						'		COALESCE(u.account_id, 0) as account_id, COALESCE(u.account_name, 0) as account_name, COALESCE(u.org_server, a.defender_server_id) as org_server, COALESCE(u.cur_server, 0) as cur_server,' +

						'		COALESCE(u.org_server, 0) as login_server, convert(nvarchar,COALESCE(u.create_date, ''1970-01-01''), 20) as create_date,' +

						'		convert(char, COALESCE(u.gender, 0)) as gender, convert(char, COALESCE(u.race, 0)) as race, convert(char, COALESCE(u.class, 0)) as class,' +

						'		convert(char, COALESCE(u.lev, 0)) as lev, convert(char, COALESCE(u.builder, 0)) as builder, COALESCE(u.world, 0) as world,' +

						'		case ' +

						'			WHEN u.last_login_time = u.last_logout_time and u.last_login_time != ''1970-01-01 00:00:00.000'' and u.last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' +

						'			WHEN u.last_login_time != u.last_logout_time or u.last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' +

						'			WHEN u.last_login_time = u.last_logout_time and u.last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' +

						'			ELSE ''silver'' ' +

						'		end as logonoff ' +

						' from abyss_user_defender a(nolock) ' +

						' left join user_data u(nolock) on a.defender_char_id=u.char_id and u.delete_type != ''10000'' and u.org_server=' + CONVERT(varchar, _world_id) +

						' where	abyss_id=''' + _abyss_id + ''' ' +

						' and	defender_char_id^update_time not in (' +

						'	select top('+_top_count+') defender_char_id^update_time ' +

						'	from abyss_user_defender a2(nolock) ' +

						'	left join user_data u2(nolock) on a2.defender_char_id=u2.char_id and u2.delete_type != ''10000'' and u2.org_server=' + CONVERT(varchar, _world_id) +

						'	where	abyss_id=''' + _abyss_id + ''' ' + _sql_where +

						'	order by a2.update_time desc, defender_rank, defender_siegepoint)'

			_sql := _sql + _sql_where

			_sql := _sql + ' order by a.update_time desc, defender_rank, defender_siegepoint'



			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssda_srchabyssdefender;
-- +goose StatementEnd
