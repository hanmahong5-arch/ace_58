-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutCanMakeSticker_20131202.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcanmakesticker_20131202(_char_id INTEGER, _can_make_sticker INTEGER, _login_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	IF NOT EXISTS (select char_id from user_app_installation(updlock) where char_id = _char_id)

	BEGIN

		INSERT INTO user_app_installation (char_id, can_make_sticker, login_time)

		VALUES (_char_id, _can_make_sticker, _login_time)

	END

	ELSE

	BEGIN

		UPDATE user_app_installation SET login_time=_login_time where char_id = _char_id

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcanmakesticker_20131202;
-- +goose StatementEnd
