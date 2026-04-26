-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_updateauctionstate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updateauctionstate(_id INTEGER, _qina BIGINT, _lastupdate INTEGER, _buyer INTEGER, _buyername TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	update user_auction set qina = _qina, lastUpdate = _lastupdate, buyerID = _buyer, buyerName = _buyername, betcount = betcount + 1 where ID = _id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updateauctionstate;
-- +goose StatementEnd
