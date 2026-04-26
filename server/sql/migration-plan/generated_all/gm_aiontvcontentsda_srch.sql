-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AionTVContentsDA_Srch.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_aiontvcontentsda_srch(_server_id INTEGER, _deleted TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted

	

	IF (_deleted != '')

	BEGIN

		SELECT	id, url, start_date, end_date, server_id, login_id, login_nm, reg_date, is_deleted

		FROM	aion_tv_contents (nolock)

		WHERE	server_id = _server_id AND is_deleted = CONVERT(tinyint, _deleted)

    ORDER BY server_id, reg_date DESC

	END

	ELSE

	BEGIN

		SELECT	id, url, start_date, end_date, server_id, login_id, login_nm, reg_date, is_deleted

		FROM	aion_tv_contents (nolock)

		WHERE	server_id = _server_id

    ORDER BY server_id, reg_date DESC

	END	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_aiontvcontentsda_srch;
-- +goose StatementEnd
