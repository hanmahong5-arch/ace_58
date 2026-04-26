-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeBuddyComment_Inter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changebuddycomment_inter(_char_id INTEGER, _buddy_id INTEGER, _serverid INTEGER, _comment TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_buddy_inter SET comment = _comment WHERE char_id = _char_id and buddy_id = _buddy_id and server_id = _serverid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changebuddycomment_inter;
-- +goose StatementEnd
