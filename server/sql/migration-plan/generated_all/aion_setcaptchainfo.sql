-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCaptchaInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcaptchainfo(_char_id INTEGER, _prohibition_flag INTEGER, _count INTEGER, _prohibition_time INTEGER, _elapsed_time INTEGER, _first_generation_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	IF EXISTS (SELECT char_id FROM user_captcha (updlock) WHERE char_id=_char_id)

		UPDATE user_captcha 

		SET prohibition_flag=_prohibition_flag, user_captcha.count=_count, prohibition_time=_prohibition_time, elapsed_time=_elapsed_time, first_generation_time=_first_generation_time

		WHERE char_id=_char_id

	ELSE

		INSERT user_captcha(char_id, prohibition_flag, user_captcha.count, prohibition_time, elapsed_time, first_generation_time)

		VALUES (_char_id, _prohibition_flag, _count, _prohibition_time, _elapsed_time, _first_generation_time)		

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcaptchainfo;
-- +goose StatementEnd
