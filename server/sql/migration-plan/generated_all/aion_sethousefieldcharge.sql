-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseFieldCharge.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethousefieldcharge(_addr INTEGER, _charge_count INTEGER, _warning_count INTEGER, _last_charge INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update house_field set chargeCount = _charge_count, warningCount=_warning_count, lastCharge = _last_charge where addr_id = _addr

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethousefieldcharge;
-- +goose StatementEnd
