-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutUsedItemOnTrading.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putuseditemontrading(_char_id INTEGER, _trade_type INTEGER, _tradeitemid BIGINT, _tradeitem_amount BIGINT, _useditem_nameid1 INTEGER, _useditem_amount1 BIGINT, _useditem_dbid1 BIGINT, _useditem_nameid2 INTEGER, _useditem_amount2 BIGINT, _useditem_dbid2 BIGINT, _useditem_nameid3 INTEGER, _useditem_amount3 BIGINT, _useditem_dbid3 BIGINT, _useditem_nameid4 INTEGER, _useditem_amount4 BIGINT, _useditem_dbid4 BIGINT, _useditem_nameid5 INTEGER, _useditem_amount5 BIGINT, _useditem_dbid5 BIGINT, _useditem_nameid6 INTEGER, _useditem_amount6 BIGINT, _useditem_dbid6 BIGINT, _used_abysspoint BIGINT, _used_money BIGINT, _status INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
insert into user_useditem_ontrading

(char_id, trade_type, tradeitemid, tradeitem_amount, useditem_nameid1, useditem_amount1, useditem_dbid1, useditem_nameid2, useditem_amount2, useditem_dbid2, useditem_nameid3, useditem_amount3, useditem_dbid3, useditem_nameid4, useditem_amount4, usedItem_dbid4, useditem_nameid5, useditem_amount5, usedItem_dbid5, useditem_nameid6, useditem_amount6, usedItem_dbid6, used_abysspoint, used_money, status, regdate)

values 

(_char_id, _trade_type, _tradeitemid, _tradeitem_amount, _useditem_nameid1, _useditem_amount1, _useditem_dbid1, _useditem_nameid2, _useditem_amount2, _useditem_dbid2, _useditem_nameid3, _useditem_amount3, _useditem_dbid3, _useditem_nameid4, _useditem_amount4, _useditem_dbid4, _useditem_nameid5, _useditem_amount5, _useditem_dbid5, _useditem_nameid6, _useditem_amount6, _useditem_dbid6, _used_abysspoint, _used_money, _status, NOW());
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putuseditemontrading;
-- +goose StatementEnd
