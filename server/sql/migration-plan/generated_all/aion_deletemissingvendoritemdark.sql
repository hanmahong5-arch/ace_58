-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteMissingVendorItemDark.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletemissingvendoritemdark()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM vendor_item_dark

WHERE   (id NOT IN

    (SELECT   vendor_item_dark.id

    FROM      vendor_item_dark INNER JOIN

        user_item ON vendor_item_dark.user_item_id = user_item.id));
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletemissingvendoritemdark;
-- +goose StatementEnd
