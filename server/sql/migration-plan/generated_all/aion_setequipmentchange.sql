-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetEquipmentChange.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setequipmentchange(_char_id INTEGER, _set_id INTEGER, _option_flags INTEGER, _item_ids BYTEA)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	UPDATE

		user_equipment_change

	SET

		option_flags = _option_flags,

		item_ids = _item_ids

	WHERE

		char_id = _char_id and set_id = _set_id



	IF @_r_o_w_c_o_u_n_t = 0

	BEGIN

		INSERT INTO user_equipment_change(char_id, option_flags, set_id, item_ids)

		VALUES (_char_id, _option_flags, _set_id, _item_ids)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setequipmentchange;
-- +goose StatementEnd
