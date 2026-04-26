-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHouseInstantScript.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseinstantscript(_user_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT slot_id, script_size, script_data

	FROM house_instant_script WHERE char_id = _user_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseinstantscript;
-- +goose StatementEnd
