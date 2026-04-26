-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFamiliarFuncExpireTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfamiliarfuncexpiretime(_char__id INTEGER, _expire_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT char_id FROM user_data_ext(UPDLOCK) where char_id = _char__id)

		BEGIN

			UPDATE user_data_ext SET familiar_func_expireTime = _expire_time where char_id = _char__id

		END

	ELSE

		BEGIN

			INSERT into user_data_ext (char_id, familiar_func_expireTime)

			VALUES (_char__id, _expire_time)

		END

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarfuncexpiretime;
-- +goose StatementEnd
