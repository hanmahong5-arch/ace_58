-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_RestrictedItemDA_SrchInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_restricteditemda_srchinfo(_type TEXT, _restrict_status TEXT, _ing TEXT, _will_be_ing TEXT, _end TEXT, _cur_date TEXT, _name_id TEXT, _world_id TEXT, _view_count TEXT, _top_count TEXT, _service_class_type TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off

			

			declare _sql nvarchar(4000), _sql_etc nvarchar(2500), _tmp tinyint

			

			_sql_etc := ' '

			_tmp := 0

			

			IF _name_id != 'null'

			BEGIN

				_sql_etc := ' and ('+_name_id+')  '

			END

			

			IF _ing != 'null' or _will_be_ing != 'null' or _end != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and ('

			END

			

			IF _ing != 'null' 

			BEGIN

				_sql_etc := _sql_etc + ' ((start_date <= '''+_cur_date+''' and end_date is NULL) or (start_date <= '''+_cur_date+''' and end_date is not NULL and end_date >= '''+_cur_date+'''))  '

				_tmp := 1

			END

			

			IF _will_be_ing != 'null' 

			BEGIN

				IF _tmp = 1

					_sql_etc := _sql_etc + ' or ((start_date > '''+_cur_date+''' and end_date is NULL) or (start_date > '''+_cur_date+''' and end_date is not NULL and end_date >= '''+_cur_date+'''))  '

				else

				begin

					_sql_etc := _sql_etc + ' ((start_date > '''+_cur_date+''' and end_date is NULL) or (start_date > '''+_cur_date+''' and end_date is not NULL and end_date >= '''+_cur_date+'''))  '

					_tmp := 1

				end

			END

			

			IF _end != 'null' 

			BEGIN

				IF _tmp = 1

					_sql_etc := _sql_etc + ' or (end_date is not NULL and end_date < '''+_cur_date+''') '

				else

				begin

					_sql_etc := _sql_etc + ' (end_date is not NULL and end_date < '''+_cur_date+''') '

				end

			END

			

			IF _ing != 'null' or _will_be_ing != 'null' or _end != 'null'

			BEGIN

				_sql_etc := _sql_etc + ')'

			END

			

			IF _type != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and type = '''+_type+'''  '

			END

			

			IF _restrict_status != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and restrict_status = '''+_restrict_status+'''  '

			END

			

			IF _service_class_type != 'null'

			BEGIN

				_sql_etc := _sql_etc + ' and service_class_type = '''+_service_class_type+'''  '

			END

			

			_sql := ' select top ' + _view_count +

					   ' convert(nvarchar,regdate,20) regdate,convert(nvarchar,START_DATE,20) START_DATE,convert(nvarchar,end_date,20) end_date,id,RESTRICTED_ID,WORLD_ID,SERVICE_TYPE,TYPE,ITEM_NAME_ID,VALUE,RESTRICT_STATUS,LOGIN_ID,LOGIN_NM,UP_INFO,SERVICE_CLASS_TYPE ' +

					   ' from restricted_item (nolock)' +

					   ' where (world_id= '''+_world_id+''' or world_id=''0'') and id not in (select top ' + _top_count + ' id from restricted_item (nolock) where  (world_id= '''+_world_id+''' or world_id=''0'') ' + _sql_etc + ' order by type, item_name_id, service_class_type) '

			

			_sql := _sql + _sql_etc



			_sql := _sql + ' order by type, item_name_id, service_class_type '

			

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_restricteditemda_srchinfo;
-- +goose StatementEnd
