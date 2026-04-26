-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetBingoLoginTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setbingologintime(_char_id INTEGER, _login_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

    UPDATE user_app_installation 

	SET	   login_time=_login_time

	WHERE  char_id=_char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setbingologintime;
-- +goose StatementEnd
