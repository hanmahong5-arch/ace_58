-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteMissingVendorItemLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletemissingvendoritemlight()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM vendor_item_light

WHERE   (id NOT IN

    (SELECT   vendor_item_light.id

    FROM      vendor_item_light INNER JOIN

        user_item ON vendor_item_light.user_item_id = user_item.id));
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletemissingvendoritemlight;
-- +goose StatementEnd
