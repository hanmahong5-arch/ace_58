-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_LoadErrorIgnoreList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loaderrorignorelist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select id, ignore from error_ignore order by id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loaderrorignorelist;
-- +goose StatementEnd
