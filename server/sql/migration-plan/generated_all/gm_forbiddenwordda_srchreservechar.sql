-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ForbiddenWordDA_SrchReserveChar.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_forbiddenwordda_srchreservechar(_world_id TEXT, _forbidden_char TEXT, _status TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(1000), _tmp int

						

			_sql := ' select top ' + _view_count +

					   ' forbidden_id, forbidden_type, forbidden_reason, world_id, forbidden_char, status, login_id, login_nm, regdate  ' +

					   ' from forbidden_char (nolock) ' +

					   ' where FORBIDDEN_ID not in (select top ' + _top_count + ' FORBIDDEN_ID from forbidden_char(nolock) where world_id='''+_world_id+''' '

			

			_sql := _sql + ' and status = '''+_status+'''  '				

			

								   			

			IF _forbidden_char != 'null'

			BEGIN				

				_sql := _sql + ' and forbidden_char like N''%'+_forbidden_char+'%'''

			END 

			

			_sql := _sql + ' order by FORBIDDEN_ID desc) '

			

					

					

			_sql := _sql + ' and status = '''+_status+'''  ' 			

			_sql := _sql + ' and world_id = '''+_world_id+''''

								   			

			IF _forbidden_char != 'null'

			BEGIN

				_sql := _sql + ' and forbidden_char like N''%'+_forbidden_char+'%'''		

			END 			

										

			_sql := _sql + ' order by FORBIDDEN_ID desc '	

				

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_forbiddenwordda_srchreservechar;
-- +goose StatementEnd
