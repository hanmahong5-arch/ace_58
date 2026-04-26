-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHouseFieldChargeAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethousefieldchargeall()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

select addr_id, building_nameid, owner_id, chargeCount, warningCount, lastCharge from house_field where owner_id > 0 and state in (3,5)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethousefieldchargeall;
-- +goose StatementEnd
