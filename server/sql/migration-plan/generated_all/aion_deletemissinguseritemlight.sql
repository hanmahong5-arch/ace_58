-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteMissingUserItemLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletemissinguseritemlight()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
/*DELETE FROM user_item 

WHERE   (id NOT IN

    (SELECT   user_item.id 

    FROM       user_item INNER JOIN

        vendor_item_light ON vendor_item_light.user_item_id = user_item.id)

        AND  warehouse = 4)*/

UPDATE user_item 

Set warehouse = 10, update_date = NOW()

WHERE   (id NOT IN

    (SELECT   user_item.id 

    FROM       user_item INNER JOIN

        vendor_item_light ON vendor_item_light.user_item_id = user_item.id)

        AND  warehouse = 4);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletemissinguseritemlight;
-- +goose StatementEnd
