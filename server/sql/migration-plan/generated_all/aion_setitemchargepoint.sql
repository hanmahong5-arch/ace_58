-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemChargePoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemchargepoint(_id BIGINT, _charge_point INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select id from user_item_charge(UPDLOCK) where id = _id) 

	begin

		update user_item_charge set charge_point = _charge_point where id = _id

	end

else 

	begin

		insert user_item_charge(id, charge_point) values (_id, _charge_point)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemchargepoint;
-- +goose StatementEnd
