-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_CheckConn_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_checkconn_ors(_from_server_id INTEGER, _db_user_id TEXT, _db_passwd TEXT, _ret INTEGER, _err_str TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql





_ret := 0

_err_str := ''
RAISE NOTICE '%', 'Check ServerConnection To ServerId(' + + cast(_from_server_id as nvarchar) + ')';



declare _connect_string	nvarchar(256)

_connect_string := ''



declare _server_name  nvarchar(128)

_server_name := ''

declare _database_name  nvarchar(64)

_database_name := ''

SELECT datasource, _database_name = database_name INTO _server_name from AionAddedService_Servername where server_id = _from_server_id

if @_rowcount = 0

begin

	_ret := -1

	_err_str := 'Cannot find serverName of server Id(' + cast(_from_server_id as nvarchar) + ')'
RAISE NOTICE '%', _err_str;

	return

end



declare _db_info nvarchar(256)

_db_info := '''' + _server_name + ''';''' + _db_user_id + ''';''' + _db_passwd + ''''



declare _val int

declare _sql	nvarchar(4000)

_sql := 'SELECT result INTO _val from openrowset (''SQLOLEDB'', ' + _db_info

			+ ', '''+ _database_name +'.aion_AddedService_Type4_MoveChar_CheckConn_local_ORS'' )'

exec sp_executesql _sql, N'_val int output', _val output



if @_error <> 0

begin

	_ret := -2;

	_err_str := 'Connection Error!!! to serverName of server Id(' + cast(_from_server_id as nvarchar) + ')'

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_checkconn_ors;
-- +goose StatementEnd
