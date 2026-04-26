-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorItemCountDark.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendoritemcountdark(_user_id INTEGER, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT count(vendor_item_Dark.id)

FROM	vendor_item_Dark(NOLOCK) INNER JOIN user_item(NOLOCK) ON vendor_item_Dark.user_item_id = user_item.id 

WHERE (user_item.warehouse = _warehouse) AND (user_item.char_id = _user_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendoritemcountdark;
-- +goose StatementEnd
