-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getItemListFreeTradeVendorLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemlistfreetradevendorlight(_ownerid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if _ownerid = 0

	select a.user_item_id, b.freetradestate  from vendor_item_light a join user_item_freeTrade b on a.user_item_id = b.id

else

	select a.user_item_id, b.freetradestate  from vendor_item_light a join user_item_freeTrade b on (a.user_item_id = b.id and a.char_id = _ownerid);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlistfreetradevendorlight;
-- +goose StatementEnd
