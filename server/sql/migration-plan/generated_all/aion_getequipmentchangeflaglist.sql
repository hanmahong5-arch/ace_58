-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetEquipmentChangeFlagList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getequipmentchangeflaglist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT 

		set_id, option_flags

	FROM

		user_equipment_change_flag

	WHERE char_id = _char_id

	ORDER BY set_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getequipmentchangeflaglist;
-- +goose StatementEnd
