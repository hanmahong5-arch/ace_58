-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetInstanceExtraCountAbyssOP.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstanceextracountabyssop(_char_id INTEGER, _number INTEGER, _extra_count INTEGER, _next_reset_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	IF _number = 0

		UPDATE user_instance_extracount

		SET next_reset_time = 0

		WHERE char_id = _char_id

	ELSE

		IF EXISTS (SELECT map_number FROM user_instance_extracount (UPDLOCK) WHERE char_id = _char_id AND map_number = _number) 

			UPDATE user_instance_extracount

			SET extra_count_abyssop = _extra_count,

				next_reset_time = _next_reset_time

			WHERE char_id = _char_id AND map_number = _number

		ELSE

			INSERT INTO user_instance_extracount VALUES(_char_id, _number, _extra_count, _next_reset_time)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstanceextracountabyssop;
-- +goose StatementEnd
