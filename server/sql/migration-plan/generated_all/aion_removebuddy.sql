-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removebuddy(_char_id INTEGER, _buddy_id INTEGER, _flag INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin tran

DELETE FROM user_buddy1 WHERE char_id = _char_id and buddy_id = _buddy_id

if (_flag = 0)

	DELETE FROM user_buddy1 WHERE char_id = _buddy_id and buddy_id = _char_id

else if (_flag = 1)

	UPDATE user_buddy1 SET delete_flag = 1 WHERE char_id = _buddy_id and buddy_id = _char_id

commit;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removebuddy;
-- +goose StatementEnd
