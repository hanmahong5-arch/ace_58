-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetClientQuickBarList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getclientquickbarlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select data_size, data from user_client_quickbar where char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getclientquickbarlist;
-- +goose StatementEnd
