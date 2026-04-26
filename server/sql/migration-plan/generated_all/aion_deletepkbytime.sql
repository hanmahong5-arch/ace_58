-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeletePkByTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletepkbytime(_pk_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM pk WHERE pk_time < _pk_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepkbytime;
-- +goose StatementEnd
