-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchUserIDsByCharIDs.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchuseridsbycharids(_cvs_char_ids TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



			DECLARE _query	nvarchar(max)

			_query := '

				SELECT	user_id, char_id, account_id, org_server

				FROM	user_data (nolock)

				WHERE	char_id IN (' + _cvs_char_ids + ')

				ORDER BY char_id '



			EXEC (_query);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchuseridsbycharids;
-- +goose StatementEnd
