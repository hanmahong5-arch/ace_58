-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveItemFromDropCtrlList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removeitemfromdropctrllist(_item_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	delete from item_drop_ctrl where item_name_id=_item_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeitemfromdropctrllist;
-- +goose StatementEnd
