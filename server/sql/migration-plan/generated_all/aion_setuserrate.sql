-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUserRate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserrate(_char_id INTEGER, _rate_id INTEGER, _mu DOUBLE PRECISION, _sigma DOUBLE PRECISION, _update_cnt INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	IF EXISTS (SELECT id FROM user_rate(updlock) WHERE char_id = _char_id AND rate_id = _rate_id)

	BEGIN

		UPDATE user_rate SET mu = _mu, sigma = _sigma, update_cnt = _update_cnt WHERE char_id = _char_id AND rate_id = _rate_id

	END

	ELSE

	BEGIN

		INSERT INTO user_rate(char_id, rate_id, mu, sigma, update_cnt) VALUES (_char_id, _rate_id, _mu, _sigma, _update_cnt)

	END    

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserrate;
-- +goose StatementEnd
