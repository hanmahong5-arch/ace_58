-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddBlock.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addblock(_char_id INTEGER, _block_id INTEGER, _comment TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if NOT EXISTS(SELECT char_id FROM user_block(updlock) WHERE char_id = _char_id and block_id = _block_id)

begin

	INSERT user_block (char_id, block_id, comment) VALUES (_char_id, _block_id, _comment)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addblock;
-- +goose StatementEnd
