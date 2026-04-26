-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetEquipmentChangeFlag.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setequipmentchangeflag(_char_id INTEGER, _set_id INTEGER, _option_flags INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF _option_flags = 0

	BEGIN

		DELETE FROM user_equipment_change_flag

		WHERE char_id = _char_id and set_id = _set_id

	END

	ELSE

	BEGIN

		UPDATE user_equipment_change_flag

		SET option_flags = _option_flags

		WHERE char_id = _char_id and set_id = _set_id



		IF @_r_o_w_c_o_u_n_t = 0

		BEGIN

			INSERT INTO user_equipment_change_flag(char_id, set_id, option_flags)

			VALUES (_char_id, _set_id, _option_flags)

		END

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setequipmentchangeflag;
-- +goose StatementEnd
