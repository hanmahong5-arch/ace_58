-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseFieldScript.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethousefieldscript(_addr_id INTEGER, _slot_id INTEGER, _script_size INTEGER, _script_data BYTEA)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT addr_id FROM house_field_script(UPDLOCK) WHERE addr_id = _addr_id AND slot_id = _slot_id)

	BEGIN

		UPDATE house_field_script SET script_size = _script_size, script_data = _script_data WHERE addr_id = _addr_id AND slot_id = _slot_id;

	END

	ELSE

	BEGIN

		INSERT house_field_script(addr_id, slot_id, script_size, script_data) VALUES (_addr_id, _slot_id, _script_size, _script_data);

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethousefieldscript;
-- +goose StatementEnd
