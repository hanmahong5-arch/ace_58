-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_fix_buddy_inter_to_local.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_fix_buddy_inter_to_local(_serverid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	insert user_buddy1 select char_id, buddy_id, delete_flag, comment from user_buddy_inter where server_id = _serverid

	DELETE FROM user_buddy_inter where server_id = _serverid

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_fix_buddy_inter_to_local;
-- +goose StatementEnd
