-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemOwner_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemowner_20111227(_id BIGINT, _char_id INTEGER, _warehouse INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item SET char_id = _char_id, warehouse = _warehouse, update_date = NOW()  WHERE id = _id

UPDATE user_item_option SET char_id = _char_id WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemowner_20111227;
-- +goose StatementEnd
