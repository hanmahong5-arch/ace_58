-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetEquipmentItemList_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getequipmentitemlist_20111227(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT a.slot, a.name_id, COALESCE(b.skin_name_id,0),COALESCE(b.proc_tool_nameid, 0),COALESCE(b.dye_info,0)

FROM user_item a (nolock) left join user_item_option b (nolock) on a.id = b.id

WHERE a.char_id = _char_id AND a.warehouse = 0 AND slot between 1 and 2;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getequipmentitemlist_20111227;
-- +goose StatementEnd
