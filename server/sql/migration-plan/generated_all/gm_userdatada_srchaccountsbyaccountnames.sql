-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchAccountsByAccountNames.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchaccountsbyaccountnames(_cvs_account_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	set transaction isolation level read uncommitted



	DECLARE _query	varchar(max)

	_query := '

		SELECT	account_id ,account_name

		FROM	user_data (nolock)

		WHERE	account_name IN (' + _cvs_account_name + ')

		GROUP BY account_id, account_name

		ORDER BY account_name '



	EXEC (_query)




end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchaccountsbyaccountnames;
-- +goose StatementEnd
