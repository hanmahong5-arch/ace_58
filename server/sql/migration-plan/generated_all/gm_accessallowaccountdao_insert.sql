-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AccessAllowAccountDAO_Insert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_accessallowaccountdao_insert(_account_id INTEGER, _account_name TEXT, _status INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	if not exists (select account_id from access_allow_account (updlock) where account_id = _account_id)

	begin

		insert into access_allow_account (account_id ,account_name, status, regdate)

		values (_account_id, _account_name, _status, NOW())

	end

	else

	begin

		update	access_allow_account

		set		status = _status

		where	account_id = _account_id

	end

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_accessallowaccountdao_insert;
-- +goose StatementEnd
