-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutVendorAverageLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putvendoraveragelight(_name_id BIGINT, _sold_unit_price BIGINT, _sold_date INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	INSERT vendor_average_light (name_id, sold_unit_price, sold_date) VALUES (_name_id, _sold_unit_price, _sold_date);

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putvendoraveragelight;
-- +goose StatementEnd
