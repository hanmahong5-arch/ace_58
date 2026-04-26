-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ForbiddenWordDA_SrchForbiddenWord.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_forbiddenwordda_srchforbiddenword(_world_id TEXT, _forbidden_word TEXT, _forbidden_type TEXT, _is_like TEXT, _forbidden_reason TEXT, _status TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(1000), _tmp int

						

			_sql := 'select top ' + _view_count +

					   ' forbidden_id, forbidden_type, forbidden_reason, is_like, world_id, forbidden_word, status, login_id, login_nm, regdate' +

					   ' from forbidden_word (nolock)' +

					   ' where FORBIDDEN_ID not in (select top ' + _top_count + ' FORBIDDEN_ID from forbidden_word(nolock) where world_id='''+_world_id+''' '

			

			_sql := _sql + ' and status = '''+_status+''' and is_like = '''+_is_like+''' '				

			

			IF _forbidden_type != '3'

			BEGIN

				_sql := _sql + ' and forbidden_type = '''+_forbidden_type+''''	

			END 

			

			IF _forbidden_reason != '100'

			BEGIN

				_sql := _sql + ' and forbidden_reason = '''+_forbidden_reason+''''	

			END 

								   			

			IF _forbidden_word != 'null'

			BEGIN				

				_sql := _sql + ' and forbidden_word like N''%'+_forbidden_word+'%'''

			END 

			

			_sql := _sql + ' order by FORBIDDEN_ID desc) '

			

			IF _forbidden_type != '3'

			BEGIN

				_sql := _sql + ' and forbidden_type ='+_forbidden_type+''				

			END 			

					

			_sql := _sql + ' and status = '''+_status+''' and is_like = '''+_is_like+''' ' 			

			_sql := _sql + ' and world_id = '''+_world_id+''''

			

			

			IF _forbidden_reason != '100'

			BEGIN

				_sql := _sql + ' and forbidden_reason = '''+_forbidden_reason+''''

			END 

					   			

			IF _forbidden_word != 'null'

			BEGIN

				_sql := _sql + ' and forbidden_word like N''%'+_forbidden_word+'%'''		

			END 			

										

			_sql := _sql + ' order by FORBIDDEN_ID desc'	

							

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_forbiddenwordda_srchforbiddenword;
-- +goose StatementEnd
