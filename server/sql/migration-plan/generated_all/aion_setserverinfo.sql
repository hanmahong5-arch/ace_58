-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetServerInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setserverinfo(_server_id INTEGER, _info_name TEXT, _int_val INTEGER, _int64_val BIGINT, _str_val TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT server_id FROM server_info(updlock) WHERE server_id= _server_id and info_name = _info_name)

begin

	UPDATE server_info SET int_value = _int_val, int64_value = _int64_val, str_value =  _str_val WHERE server_id= _server_id and info_name = _info_name

end	

else

begin

	INSERT server_info (server_id, info_name, int_value, int64_value, str_value) VALUES (_server_id, _info_name, _int_val, _int64_val, _str_val)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setserverinfo;
-- +goose StatementEnd
