-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addbuddy(_char_id INTEGER, _buddy_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if NOT EXISTS(SELECT char_id FROM user_buddy1(updlock) WHERE char_id = _char_id and buddy_id = _buddy_id)

begin

	INSERT user_buddy1 (char_id, buddy_id, delete_flag) VALUES (_char_id, _buddy_id, 0)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addbuddy;
-- +goose StatementEnd
