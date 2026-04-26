-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemPreserved.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitempreserved(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item SET warehouse=16, update_date=NOW()  WHERE char_id=_char_id AND warehouse=0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitempreserved;
-- +goose StatementEnd
