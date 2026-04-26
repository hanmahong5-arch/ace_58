-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteItemByChar.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitembychar(_char_id INTEGER, _warehouse INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
/*** DELETE FROM user_item WHERE char_id = _char_id AND warehouse = _warehouse ***/

Update user_item 

Set warehouse=10, update_date=NOW()

WHERE char_id = _char_id AND warehouse = _warehouse;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitembychar;
-- +goose StatementEnd
