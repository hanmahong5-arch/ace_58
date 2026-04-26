-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_changeoldcharactername.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changeoldcharactername(_char_id INTEGER, _server_id INTEGER, _buddy_name TEXT, _char_id INTEGER, _server_id INTEGER, _buddy_name TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update user_buddy_inter set server_id = _server_id, buddy_id = _char_id, buddy_name=_buddy_name where server_id = _server_id and buddy_id = _char_id and buddy_name = _buddy_name

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changeoldcharactername;
-- +goose StatementEnd
