-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ClearCaptchaInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearcaptchainfo()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	DELETE FROM user_captcha;

    --TRUNCATE TABLE user_captcha

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearcaptchainfo;
-- +goose StatementEnd
