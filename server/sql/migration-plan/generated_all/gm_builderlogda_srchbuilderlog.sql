-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_BuilderLogDA_SrchBuilderLog.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_builderlogda_srchbuilderlog(_char_nm TEXT, _build_nm TEXT, _view_count TEXT, _top_count TEXT, _from_date TEXT, _to_date TEXT, _builder_lv TEXT, _command_from TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



	set transaction isolation level read uncommitted

	set ansi_warnings off

	

	declare _sql nvarchar(1500), _sql_tmp nvarchar(300), _tmp int

	

	_sql_tmp := ' '

	

	IF _char_nm != 'null'

	BEGIN

		_sql_tmp := _sql_tmp + ' and CHAR_NM = N'''+_char_nm+''''

	END

	IF _build_nm != 'null'

	BEGIN

		_sql_tmp := _sql_tmp + ' and BUILD_NM = N'''+_build_nm+''''

	END

	IF _builder_lv != 'null'

	BEGIN

		_sql_tmp := _sql_tmp + ' and builder_lv = '''+_builder_lv+''''

	END

	IF _command_from != ''

	BEGIN

		_sql_tmp := _sql_tmp + ' and command_from = '''+_command_from+''''

	END

	

	_sql := ' select top ' + _view_count + ' BUILDER_LOG_ID, WORLD_ID, CHAR_NM, TARGET_CHAR_NM, BUILD_NM, BUILD_PARAMETER, BUILDER_TYPE, BUILDER_LV, convert(nvarchar,REGDATE,20 ) REGDATE, COMMAND_FROM, RESULT_MESSAGE ' +

			   ' from	builder_log (nolock) ' +

			   ' where	BUILDER_LOG_ID not in(select top ' + _top_count + ' BUILDER_LOG_ID from builder_log(nolock) where regdate between '''+_from_date+''' and '''+_to_date+''' '+_sql_tmp+' order by BUILDER_LOG_ID desc) ' +

			   ' and	regdate between '''+_from_date+''' and '''+_to_date+''' '+_sql_tmp+

			   ' order by BUILDER_LOG_ID desc '

	

	exec Sp_ExecuteSQL _sql

	


	return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_builderlogda_srchbuilderlog;
-- +goose StatementEnd
