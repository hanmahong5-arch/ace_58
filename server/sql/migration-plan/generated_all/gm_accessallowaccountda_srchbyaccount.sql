-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AccessAllowAccountDA_SrchByAccount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_accessallowaccountda_srchbyaccount(_account_id INTEGER, _account_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	set transaction isolation level read uncommitted



	if (_account_id is not null and _account_name is not null)

	begin

		select	access_id, account_id ,account_name, status, regdate

		from	access_allow_account

		where	account_id = _account_id

		and		account_name = _account_name

	end

	else if (_account_id is not null)

	begin

		select	access_id, account_id ,account_name, status, regdate

		from	access_allow_account

		where	account_id = _account_id

	end

	else if (_account_name is not null)

	begin

		select	access_id, account_id ,account_name, status, regdate

		from	access_allow_account

		where	account_name = _account_name

	end




end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_accessallowaccountda_srchbyaccount;
-- +goose StatementEnd
