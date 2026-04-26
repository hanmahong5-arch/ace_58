-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCaptchaInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcaptchainfo(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    SELECT prohibition_flag, user_captcha.count, prohibition_time, elapsed_time, first_generation_time 

	FROM user_captcha WHERE char_id=_char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcaptchainfo;
-- +goose StatementEnd
