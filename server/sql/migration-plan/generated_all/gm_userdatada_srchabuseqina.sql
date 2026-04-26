-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchAbuseQina.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchabuseqina(_world_id TEXT, _user_id TEXT, _account_name TEXT, _bx_char_id TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(4000), _tmp int, _sql_etc nvarchar(1000)



			_sql_etc := ' and delete_type != ''10000'' '



			IF _user_id != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and user_id = N'''+_user_id+''''				

			END

			

			IF _bx_char_id != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and char_id = '''+_bx_char_id+''''				

			END 

			

			IF _account_name != 'null'

			BEGIN

					_sql_etc := _sql_etc + ' AND account_name = '''+_account_name+''''

			END

									

			_sql := 'select top ' + _view_count +

					   ' 	delete_type, delete_complete_date, inventory_growth, char_warehouse_growth, delete_date, char_id, user_id, account_id, account_name, org_server, cur_server,COALESCE(login_server, org_server) login_server,' +

					   ' 	convert(nvarchar,create_date,20 ) create_date, convert(char, gender) gender, convert(char, race) race, convert(char, class) class, convert(char, lev) lev, convert(char, builder) builder, exp, world,	' +					   

					   '   case ' +

					   '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' +

				       '     WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' +					  

				       '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' +

					   '   end as logonoff, t2.* '+				   

					   ' from user_data t1(nolock), qina_manipulate t2(nolock)' +

					   ' where t1.char_id=t2.charid and t2.qina_id not in(select top ' + _top_count + ' t2.qina_id from user_data t1(nolock), qina_manipulate t2(nolock) where t1.char_id=t2.charid and org_server='''+_world_id+''' ' + _sql_etc + '  order by t2.qina_id desc) '

						

			_sql := _sql + _sql_etc

			

			_sql := _sql + ' and org_server = '''+_world_id+''''		

			

			_sql := _sql + ' order by t2.qina_id desc '

					

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchabuseqina;
-- +goose StatementEnd
