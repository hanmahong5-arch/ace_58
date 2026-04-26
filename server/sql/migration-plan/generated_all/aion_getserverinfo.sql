-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetServerInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getserverinfo(_server_id INTEGER, _info_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select int_value, int64_value, str_value

from server_info

where server_id = _server_id and info_name <= _info_name;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getserverinfo;
-- +goose StatementEnd
