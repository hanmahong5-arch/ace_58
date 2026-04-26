-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeletePk.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletepk(_pk_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM pk WHERE pk_id = _pk_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepk;
-- +goose StatementEnd
