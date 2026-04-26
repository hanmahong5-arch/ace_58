-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AccessAllowAccountDA_SrchAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_accessallowaccountda_srchall(_view_count INTEGER, _page INTEGER, _status INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	set transaction isolation level read uncommitted



	if (_status is null)

	begin

		select	top (_view_count) access_id, account_id ,account_name, status, regdate

		from	access_allow_account (nolock)

		where	access_id not in (select top (_view_count*(_page-1)) access_id from access_allow_account (nolock) order by account_name)

		order by account_name

	end

	else

	begin

		select	top (_view_count) access_id, account_id ,account_name, status, regdate

		from	access_allow_account (nolock)

		where	access_id not in (select top (_view_count*(_page-1)) access_id from access_allow_account (nolock) order by account_name)

		and		status = _status

		order by account_name

	end




end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_accessallowaccountda_srchall;
-- +goose StatementEnd
