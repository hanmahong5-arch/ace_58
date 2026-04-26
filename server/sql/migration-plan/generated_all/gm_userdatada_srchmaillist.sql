-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchMailList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchmaillist(_world_id TEXT, _builder TEXT, _char_on TEXT, _from_char_id TEXT, _to_char_id TEXT, _from_lev TEXT, _to_lev TEXT, _from_create_date TEXT, _to_create_date TEXT, _race TEXT, _class_str TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(4000), _sql_etc nvarchar(1000)

			

			_sql_etc := ' '

			

			IF _char_on = 'Y'

			BEGIN

				_sql_etc := _sql_etc + ' and last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' '				

			END

			

			IF _from_char_id != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and char_id between '''+_from_char_id+''' and '''+_to_char_id+''' '				

			END 

			

			IF _from_lev != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and lev between '''+_from_lev+''' and '''+_to_lev+''' '				

			END			



			IF _from_create_date != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and create_date between '''+_from_create_date+''' and '''+_to_create_date+''' '				

			END 

			

			IF _race != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and race = '''+_race+''''				

			END 

			

			IF _class_str != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and ('+_class_str+') '				

			END



						

			_sql := ' select lev, exp, account_id, char_id, user_id from user_data (nolock)' +

				        ' where delete_date=0 and org_server='''+_world_id+''' and builder='''+_builder+''' ' + _sql_etc

				       

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchmaillist;
-- +goose StatementEnd
