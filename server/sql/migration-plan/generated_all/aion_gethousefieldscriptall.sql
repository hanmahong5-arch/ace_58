-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHouseFieldScriptAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethousefieldscriptall()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT addr_id, slot_id, script_size, script_data

	FROM house_field_script

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethousefieldscriptall;
-- +goose StatementEnd
