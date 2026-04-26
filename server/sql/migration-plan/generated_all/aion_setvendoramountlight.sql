-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetVendorAmountLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setvendoramountlight(_vendor_item_id INTEGER, _amount BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE vendor_item_light

SET	remain_amount = _amount

WHERE (id = _vendor_item_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setvendoramountlight;
-- +goose StatementEnd
