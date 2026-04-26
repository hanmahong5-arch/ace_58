-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_ServerInfoDA_SrchServerInfoBycond.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_serverinfoda_srchserverinfobycond(_server_id TEXT, _info_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	server_id, info_name, int_value, int64_value, str_value 

			from	server_info (nolock)

			where	server_id=_server_id and info_name=''+_info_name+'';
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_serverinfoda_srchserverinfobycond;
-- +goose StatementEnd
