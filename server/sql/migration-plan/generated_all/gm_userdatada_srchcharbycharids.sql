-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCharByCharIDs.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbycharids(_csv_char_ids TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

			DECLARE	_query	varchar(4000)

			_query := 'SELECT char_id, user_id, account_id, account_name, org_server, cur_server, gender, race, class, lev, builder, create_date FROM user_data (nolock) WHERE char_id IN (' + _csv_char_ids + ')'

			EXEC(_query)

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcharbycharids;
-- +goose StatementEnd
