-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveAllBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removeallbuddy(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
--DELETE FROM user_buddy1 WHERE char_id = _char_id

DELETE FROM user_buddy1 WHERE buddy_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeallbuddy;
-- +goose StatementEnd
