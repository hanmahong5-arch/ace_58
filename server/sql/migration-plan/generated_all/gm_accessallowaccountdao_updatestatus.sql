-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AccessAllowAccountDAO_UpdateStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_accessallowaccountdao_updatestatus(_account_id INTEGER, _status INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update	access_allow_account

	set		status = _status

	where	account_id = _account_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_accessallowaccountdao_updatestatus;
-- +goose StatementEnd
