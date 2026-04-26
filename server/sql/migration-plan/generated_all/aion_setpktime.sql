-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPkTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpktime(_pk_id INTEGER, _pk_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE pk SET pk_time = _pk_time WHERE pk_id = _pk_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpktime;
-- +goose StatementEnd
