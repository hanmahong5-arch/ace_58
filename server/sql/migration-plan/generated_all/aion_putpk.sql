-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutPk.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putpk(_pk_id INTEGER, _pk_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT pk (pk_id,pk_time) VALUES (_pk_id, _pk_time);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpk;
-- +goose StatementEnd
