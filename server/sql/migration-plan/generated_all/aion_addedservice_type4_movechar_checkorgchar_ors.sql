-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_CheckOrgChar_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_checkorgchar_ors(_from_server_id INTEGER, _server_id INTEGER, _db_user_id TEXT, _db_passwd TEXT, _char_id INTEGER, _char_name TEXT, _premium INTEGER, _with_account_warehouse INTEGER, _online INTEGER, _ret INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql





declare _connect_string	nvarchar(256)

_connect_string := ''



declare _server_name  nvarchar(128)

_server_name := ''

declare _database_name  nvarchar(64)

_database_name := ''

SELECT datasource, _database_name = database_name INTO _server_name from AionAddedService_Servername where server_id = _from_server_id

if @_rowcount = 0

begin

	_ret := -10101

	return

end



declare _db_info nvarchar(256)

_db_info := '''' + _server_name + ''';''' + _db_user_id + ''';''' + _db_passwd + ''''



declare _val int

declare _sql	nvarchar(4000)

_sql := 'SELECT result INTO _val from openrowset (''SQLOLEDB'', ' + _db_info

			+ ', ''' + _database_name + '.aion_AddedService_Type4_MoveChar_CheckOrgChar_local_ORS ' + cast(_from_server_id as nvarchar) 

			+ ', ' + cast(_server_id as nvarchar) 

			+ ', ' + cast(_char_id as nvarchar) 

			+ ', ''''' + _char_name + ''''' '

			+ ', ' + CAST(_premium as nvarchar)

			+ ', ' + CAST(_with_account_warehouse as nvarchar)

			+ ', ' + cast(_online as nvarchar) + ''' )'

--print _sql

exec sp_executesql _sql, N'_val int output', _val output

if @_error <> 0 _ret := -10102;

else _ret := _val



return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_checkorgchar_ors;
-- +goose StatementEnd
