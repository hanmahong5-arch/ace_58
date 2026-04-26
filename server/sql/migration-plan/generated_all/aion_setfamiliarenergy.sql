-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFamiliarEnergy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfamiliarenergy(_char_id INTEGER, _familiar_energy INTEGER, _familiar_energy_auto_charge INTEGER, _last_summon_familiar INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT char_id FROM user_data_ext(UPDLOCK) where char_id = _char_id)

		BEGIN

			UPDATE user_data_ext

			SET	familiar_energy= _familiar_energy,

				familiar_energy_autocharge = _familiar_energy_auto_charge,

				last_summon_familiar = _familiar_energy

			WHERE char_id = _char_id

		END

	ELSE

		BEGIN

			INSERT into user_data_ext (char_id, familiar_energy, familiar_energy_autocharge, last_summon_familiar)

			VALUES (_char_id, _familiar_energy, _familiar_energy_auto_charge, _familiar_energy)

		END

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarenergy;
-- +goose StatementEnd
