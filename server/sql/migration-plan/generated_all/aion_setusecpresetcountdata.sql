-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUseCPResetCountData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setusecpresetcountdata(_char_id INTEGER, _usecp_resetcount INTEGER, _next_usecp_resetcount_dec_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT char_id FROM user_data_ext(UPDLOCK) where char_id = _char_id)

		BEGIN

			UPDATE user_data_ext

			SET	usecp_resetcount= _usecp_resetcount,

				next_usecp_resetcount_dec_time = _next_usecp_resetcount_dec_time

			WHERE char_id = _char_id

		END

	ELSE

		BEGIN

			INSERT into user_data_ext (char_id, usecp_resetcount, next_usecp_resetcount_dec_time)

			VALUES (_char_id, _usecp_resetcount, _next_usecp_resetcount_dec_time)

		END

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setusecpresetcountdata;
-- +goose StatementEnd
