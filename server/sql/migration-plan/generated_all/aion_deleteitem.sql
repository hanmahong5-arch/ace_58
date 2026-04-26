-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitem(_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_item WHERE id = _id

DELETE FROM user_item_option WHERE id = _id 

DELETE FROM user_item_charge WHERE id = _id 

DELETE FROM user_item_polish where id = _id

delete from user_item_attribute where id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitem;
-- +goose StatementEnd
