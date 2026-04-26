-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateAmountForSellRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updateamountforsellrecovery(_char_id INTEGER, _warehouse INTEGER, _useditem_nameid INTEGER, _useditem_amount BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
update user_item set amount -= _useditem_amount where id = (

SELECT id from user_item where char_id=_char_id and warehouse=_warehouse and name_id=_useditem_nameid and amount >= _useditem_amount order by id desc) /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updateamountforsellrecovery;
-- +goose StatementEnd
