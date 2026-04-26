-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeBlockComment_Inter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changeblockcomment_inter(_char_id INTEGER, _block_id INTEGER, _serverid INTEGER, _comment TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_block_inter SET comment = _comment WHERE char_id = _char_id and block_id = _block_id and server_id = _serverid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changeblockcomment_inter;
-- +goose StatementEnd
