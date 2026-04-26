-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchMoveCharByWorldorUserIDorAccountNMorCnt.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchmovecharbyworldoruseridoraccountnmorcnt(_world_id TEXT, _user_id TEXT, _account_name TEXT, _builder TEXT, _deleted_char TEXT, _char_on TEXT, _deleted_move TEXT, _bx_char_id TEXT, _multi_user_ids TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(4000), _sql_etc nvarchar(1000)

			

			_sql_etc := ' '

			

			IF _account_name != 'null'

			BEGIN				

				_sql_etc := _sql_etc + ' and t1.account_name = '''+_account_name+''''				

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



			IF _builder IS NOT NULL

			BEGIN

				IF _builder = 95

					BEGIN

						_sql_etc := _sql_etc + ' and builder > ''0'' '

					END

				ELSE

					BEGIN					

						_sql_etc := _sql_etc + ' and builder = '''+_builder+''''								

					END				

			END

						

			_sql := ' select top ' + _view_count +

						' 	delete_type, delete_complete_date, inventory_growth, char_warehouse_growth, delete_date, b.char_id, user_id, account_id, account_name, org_server, cur_server,	' +

					   ' 	convert(nvarchar,create_date,20 ) create_date, convert(char, gender) gender, convert(char, race) race, convert(char, class) class, convert(char, lev) lev, convert(char, builder) builder, exp, world,	' +					   

					   '   case ' +

					   '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' +

				       '     WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' +					  

				       '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' +

					   '   end as logonoff '+	

								'from'+

								'('+

								'	select t2.char_id from('+

								'	select c.account_name'+

								'	from('+

								'	select race, account_name from user_data (nolock)'+

								'	where delete_date=0 and org_server='''+_world_id+''' '+

								'	group by race, account_name) c'+

								'	group by c.account_name'+

								'	having count(*) > 1) t1, user_data t2(nolock)'+

								'	where t1.account_name=t2.account_name and delete_date=0 and org_server='''+_world_id+''' '+

								+ _sql_etc +

								') b, user_data f(nolock)'+

								'where b.char_id=f.char_id and f.char_id not in '+

								'('+

								'	select top ' + _top_count + ' t2.char_id from('+

								'	select c.account_name'+

								'	from('+

								'	select race, account_name from user_data (nolock)'+

								'	where delete_date=0 and org_server='''+_world_id+''' '+

								'	group by race, account_name) c'+

								'	group by c.account_name'+

								'	having count(*) > 1) t1, user_data t2(nolock)'+

								'	where t1.account_name=t2.account_name and delete_date=0 and org_server='''+_world_id+''' '+

								+ _sql_etc +

								')'

					

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchmovecharbyworldoruseridoraccountnmorcnt;
-- +goose StatementEnd
