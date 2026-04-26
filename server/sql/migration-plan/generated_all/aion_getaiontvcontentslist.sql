-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetAionTVContentsList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getaiontvcontentslist(_server_id INTEGER, _cur_date BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT id, url, start_date, end_date, server_id

	FROM	aion_tv_contents (nolock)

	WHERE	server_id = _server_id AND _cur_date <= end_date AND is_deleted = 0

	ORDER BY id DESC

END /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getaiontvcontentslist;
-- +goose StatementEnd
