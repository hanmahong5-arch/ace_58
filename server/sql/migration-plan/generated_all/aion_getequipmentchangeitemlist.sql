-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetEquipmentChangeItemList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getequipmentchangeitemlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT 

		set_id, eqslot, item_id

	FROM

		user_equipment_change_item

	WHERE char_id = _char_id

	ORDER BY set_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getequipmentchangeitemlist;
-- +goose StatementEnd
