-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateForBuyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updateforbuyrecovery(_char_id INTEGER, _warehouse INTEGER, _db_id BIGINT, _tradeitem_amount BIGINT, _tradeitemid BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_item 

set warehouse=_warehouse, amount-=_tradeitem_amount 

where id=_db_id and char_id=_char_id and warehouse=0 and name_id=_tradeitemid and amount>=_tradeitem_amount;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updateforbuyrecovery;
-- +goose StatementEnd
