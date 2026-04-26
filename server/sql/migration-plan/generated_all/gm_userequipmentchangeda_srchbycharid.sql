-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserEquipmentChangeDA_SrchByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userequipmentchangeda_srchbycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SET transaction isolation level read uncommitted

	SELECT 

		set_id, eqslot, item_id

	FROM

		user_equipment_change_item(nolock)

	WHERE char_id = _char_id

	ORDER BY set_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userequipmentchangeda_srchbycharid;
-- +goose StatementEnd
