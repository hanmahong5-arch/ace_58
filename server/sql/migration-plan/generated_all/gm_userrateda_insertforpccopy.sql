-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRateDA_InsertForPCCopy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrateda_insertforpccopy(_char_id INTEGER, _rate_id INTEGER, _mu DOUBLE PRECISION, _sigma DOUBLE PRECISION, _update_cnt INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	INSERT INTO user_rate(char_id, rate_id, mu, sigma, update_cnt)

	VALUES (_char_id, _rate_id, _mu, _sigma, _update_cnt)



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrateda_insertforpccopy;
-- +goose StatementEnd
