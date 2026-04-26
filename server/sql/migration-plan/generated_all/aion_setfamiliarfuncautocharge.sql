-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFamiliarFuncAutoCharge.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfamiliarfuncautocharge(_char__id INTEGER, _func_auto_charge INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT char_id FROM user_data_ext(UPDLOCK) where char_id = _char__id)

		BEGIN

			UPDATE user_data_ext SET familiar_func_autocharge = _func_auto_charge where char_id = _char__id

		END

	ELSE

		BEGIN

			INSERT into user_data_ext (char_id, familiar_func_autocharge)

			VALUES (_char__id, _func_auto_charge)

		END

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarfuncautocharge;
-- +goose StatementEnd
