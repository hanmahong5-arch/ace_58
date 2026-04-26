-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorItemListExpiredLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendoritemlistexpiredlight(_expire_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT   vendor_item_light.id, vendor_item_light.char_id, 

	   vendor_item_light.user_item_id, vendor_item_light.remain_amount, 

	   user_data.user_id

FROM      vendor_item_light INNER JOIN

                user_data ON vendor_item_light.char_id = user_data.char_id

WHERE   (vendor_item_light.commit_date < _expire_time);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendoritemlistexpiredlight;
-- +goose StatementEnd
