-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemWarehouse_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemwarehouse_20111227(_id BIGINT, _warehouse INTEGER, _ownerid INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item

SET warehouse=_warehouse, char_id = _ownerid, update_date=NOW()

WHERE id=_id



UPDATE user_item_option

SET char_id = _ownerid

WHERE id=_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemwarehouse_20111227;
-- +goose StatementEnd
