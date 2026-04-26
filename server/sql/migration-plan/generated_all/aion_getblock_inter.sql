-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetBlock_inter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getblock_inter(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT block_id, block_name, comment, server_id FROM user_block_inter where char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblock_inter;
-- +goose StatementEnd
