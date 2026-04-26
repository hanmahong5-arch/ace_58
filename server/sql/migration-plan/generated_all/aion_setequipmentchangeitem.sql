-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetEquipmentChangeItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setequipmentchangeitem(_char_id INTEGER, _set_id INTEGER, _eqslot INTEGER, _item_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF _item_id = 0

	BEGIN

		DELETE FROM user_equipment_change_item

		WHERE char_id = _char_id and set_id = _set_id and eqslot = _eqslot

	END

	ELSE

	BEGIN

		UPDATE user_equipment_change_item

		SET item_id = _item_id

		WHERE char_id = _char_id and set_id = _set_id and eqslot = _eqslot



		IF @_r_o_w_c_o_u_n_t = 0

		BEGIN

			INSERT INTO user_equipment_change_item(char_id, set_id, eqslot, item_id)

			VALUES (_char_id, _set_id, _eqslot, _item_id)

		END

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setequipmentchangeitem;
-- +goose StatementEnd
