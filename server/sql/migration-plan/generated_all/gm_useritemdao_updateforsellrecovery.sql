-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateForSellRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updateforsellrecovery(_char_id INTEGER, _warehouse INTEGER, _tradeitem_amount BIGINT, _tradeitemid BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_item set warehouse=0, amount=_tradeitem_amount 

where id=_tradeitemid 

and char_id=_char_id 

and warehouse=_warehouse;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updateforsellrecovery;
-- +goose StatementEnd
