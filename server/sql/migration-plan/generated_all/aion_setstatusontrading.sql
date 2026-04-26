-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetStatusOnTrading.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setstatusontrading(_char_id INTEGER, _trade_type INTEGER, _tradeitemid BIGINT, _status INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_useditem_ontrading set trade_type=_trade_type, status=_status

	where char_id=_char_id and tradeitemid = _tradeitemid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setstatusontrading;
-- +goose StatementEnd
