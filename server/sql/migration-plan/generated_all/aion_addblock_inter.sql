-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddBlock_inter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addblock_inter(_char_id INTEGER, _block_id INTEGER, _serverid INTEGER, _comment TEXT, _blockname TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if NOT EXISTS(SELECT char_id FROM user_block_inter WHERE char_id = _char_id and block_id = _block_id)

begin

	INSERT user_block_inter (char_id, block_id, block_name, comment, server_id) VALUES (_char_id, _block_id, _blockname, _comment, _serverid)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addblock_inter;
-- +goose StatementEnd
