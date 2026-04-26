-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutBingoMissionData_20140122.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putbingomissiondata_20140122(_guid INTEGER, _bingo_type INTEGER, _bingo_nameid INTEGER, _status INTEGER, _account_id INTEGER, _amount INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	INSERT INTO user_bingo (guid, bingo_type, bingo_nameid, status, regdate, account_id, amount)

	VALUES (_guid, _bingo_type, _bingo_nameid, _status, NOW(), _account_id, _amount)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbingomissiondata_20140122;
-- +goose StatementEnd
