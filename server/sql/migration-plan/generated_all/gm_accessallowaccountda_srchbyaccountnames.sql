-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AccessAllowAccountDA_SrchByAccountNames.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_accessallowaccountda_srchbyaccountnames(_cvs_account_name TEXT, _view_count INTEGER, _page INTEGER, _status INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	set transaction isolation level read uncommitted



	DECLARE _query	varchar(max)

	_query := '

		SELECT	top (' + CONVERT(varchar,_view_count) + ') access_id, account_id ,account_name, status, regdate

		FROM	access_allow_account (nolock)

		WHERE	access_id NOT IN (	SELECT top (' + CONVERT(varchar, _view_count*(_page-1)) + ') access_id 

									FROM access_allow_account (nolock) 

									WHERE	account_name IN (' +_cvs_account_name+ ') 

									AND		(' + CONVERT(varchar, COALESCE(_status, '-1')) + '=-1 OR status = ' + CONVERT(varchar, COALESCE(_status, '-1')) + ')

									ORDER BY account_name )

		AND		account_name IN (' + _cvs_account_name + ')

		AND		(' + CONVERT(varchar, COALESCE(_status, '-1')) + '=-1 OR status = ' + CONVERT(varchar, COALESCE(_status, '-1')) + ')

		ORDER BY account_name '



	EXEC (_query)




end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_accessallowaccountda_srchbyaccountnames;
-- +goose StatementEnd
