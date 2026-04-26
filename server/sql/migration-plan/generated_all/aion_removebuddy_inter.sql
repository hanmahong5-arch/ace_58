-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveBuddy_inter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removebuddy_inter(_char_id INTEGER, _buddy_id INTEGER, _flag INTEGER, _server_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if (_flag = 0)	

	UPDATE user_buddy_inter SET delete_flag = 1 WHERE char_id = _char_id and buddy_id = _buddy_id and server_id = _server_id

else

	DELETE FROM user_buddy_inter WHERE char_id = _char_id and buddy_id = _buddy_id and server_id = _server_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removebuddy_inter;
-- +goose StatementEnd
