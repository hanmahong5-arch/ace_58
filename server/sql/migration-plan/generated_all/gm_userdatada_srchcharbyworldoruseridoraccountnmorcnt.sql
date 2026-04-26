-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCharByWorldorUserIDorAccountNMorCnt.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbyworldoruseridoraccountnmorcnt(_world_id TEXT, _user_id TEXT, _account_name TEXT, _builder TEXT, _deleted_char TEXT, _char_on TEXT, _deleted_move TEXT, _bx_char_id TEXT, _multi_user_ids TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(4000), _tmp int, _sql_etc nvarchar(1000), _tmp2 int



			_sql_etc := ' and delete_type != ''10000'' '

			_tmp := 1

			_tmp2 := 0

			

			IF _char_on != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' '				

			END

			

			IF _deleted_move != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and delete_type != ''0''  '

				_tmp2 := 1

			END

			

			IF _deleted_char != 'null'

			BEGIN

				IF _tmp2 = 0

					_sql_etc := _sql_etc + ' and delete_date = '''+_deleted_char+''' '

			END

			

			IF _bx_char_id != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and char_id = '''+_bx_char_id+''''

			END

			

			IF _user_id != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and user_id = N'''+_user_id+''''

			END

			

			IF _multi_user_ids != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and ('+_multi_user_ids+') '

			END

			

			IF _account_name != 'null'

			BEGIN

				IF _tmp = 1

					_sql_etc := _sql_etc + ' AND account_name = '''+_account_name+''''

				ELSE

					BEGIN

						_sql_etc := _sql_etc + ' WHERE account_name = '''+_account_name+''''

						_tmp := 1

					END

			END

			

			--IF _builder != 'null'

			IF _builder IS NOT NULL

			BEGIN

				IF _builder = '95'

					BEGIN

						IF _tmp = 1

							_sql_etc := _sql_etc + ' AND builder > ''0'' '

						ELSE

							BEGIN

								_sql_etc := _sql_etc + ' WHERE builder > ''0'' '

								_tmp := 1

							END

					END

				ELSE

					BEGIN

						IF _tmp = 1

							_sql_etc := _sql_etc + ' AND builder = '''+_builder+''''

						ELSE

							BEGIN

								_sql_etc := _sql_etc + ' WHERE builder = '''+_builder+''''

								_tmp := 1

							END

					END

			END

			

			_sql := 'select top ' + _view_count +

						' 	delete_type, delete_complete_date, inventory_growth, char_warehouse_growth, delete_date, char_id, user_id, account_id, account_name, org_server, cur_server,COALESCE(login_server, org_server) login_server,' +

						' 	convert(nvarchar,create_date,20 ) create_date, convert(char, gender) gender, convert(char, race) race, convert(char, class) class, convert(char, lev) lev, convert(char, builder) builder, exp, world,	' +

						'   case ' +

						'     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' +

						'     WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' +					  

						'     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' +

						'   end as logonoff '+

						-- [4.71] 가챠

						'	, gotcha_fever_point, gotcha_fever_expire_time '+

						' from user_data (nolock) ' +

						' where char_id not in(select top ' + _top_count + ' char_id from user_data (nolock) where org_server='''+_world_id+''' ' + _sql_etc + '  order by char_id desc) '

			

			_sql := _sql + _sql_etc

			

			_sql := _sql + ' and org_server = '''+_world_id+''''

			

			_sql := _sql + ' order by char_id desc '

			

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcharbyworldoruseridoraccountnmorcnt;
-- +goose StatementEnd
