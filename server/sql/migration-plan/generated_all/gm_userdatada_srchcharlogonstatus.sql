-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCharLogonStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharlogonstatus(_csv_char_ids TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

			DECLARE	_query	varchar(4000)

			_query := '

					SELECT	char_id,

							CASE WHEN last_login_time = last_logout_time AND last_login_time != ''1970-01-01 00:00:00.000'' THEN ''on'' ELSE ''off'' END AS ''logonoff''

					FROM	user_data (nolock)

					WHERE	char_id IN (' + _csv_char_ids + ')'

			EXEC(_query)

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcharlogonstatus;
-- +goose StatementEnd
