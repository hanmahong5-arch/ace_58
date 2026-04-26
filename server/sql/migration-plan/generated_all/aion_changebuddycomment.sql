-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeBuddyComment.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changebuddycomment(_char_id INTEGER, _buddy_id INTEGER, _comment TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_buddy1 SET  comment= _comment WHERE char_id = _char_id and buddy_id = _buddy_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changebuddycomment;
-- +goose StatementEnd
