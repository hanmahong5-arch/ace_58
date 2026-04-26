-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetBlock.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getblock(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT block_id, user_id, comment FROM user_block AS b INNER JOIN user_data AS d ON b.block_id=d.char_id WHERE b.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblock;
-- +goose StatementEnd
