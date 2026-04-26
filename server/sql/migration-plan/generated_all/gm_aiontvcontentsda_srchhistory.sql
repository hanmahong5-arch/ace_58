-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AionTVContentsDA_SrchHistory.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_aiontvcontentsda_srchhistory(_server_id INTEGER, _start_date INTEGER, _end_date INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted

	

	SELECT	id, url, start_date, end_date, server_id, login_id, login_nm, reg_date, is_deleted

	FROM	aion_tv_contents (nolock)

	WHERE	server_id = _server_id AND _start_date <= end_date AND start_date <= _end_date

	ORDER BY server_id, reg_date DESC

		

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_aiontvcontentsda_srchhistory;
-- +goose StatementEnd
