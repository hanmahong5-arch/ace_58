-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchMyUsedItemsOnTrading.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyuseditemsontrading(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			SELECT	used_id, char_id, trade_type, tradeitemid, tradeitem_amount

					, COALESCE(useditem_nameid1, 0) as useditem_nameid1, COALESCE(useditem_amount1, 0) as useditem_amount1, COALESCE(useditem_nameid2, 0) as useditem_nameid2, COALESCE(useditem_amount2, 0) as useditem_amount2, COALESCE(useditem_nameid3, 0) as useditem_nameid3, COALESCE(useditem_amount3, 0) as useditem_amount3

					, used_abysspoint, used_money, status, convert(nvarchar,regdate,20) regdate

					, COALESCE(useditem_nameid4, 0) as useditem_nameid4, COALESCE(useditem_amount4, 0) as useditem_amount4, COALESCE(useditem_nameid5, 0) as useditem_nameid5, COALESCE(useditem_amount5, 0) as useditem_amount5, COALESCE(useditem_nameid6, 0) as useditem_nameid6, COALESCE(useditem_amount6, 0) as useditem_amount6

			FROM	user_useditem_ontrading

			WHERE	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchmyuseditemsontrading;
-- +goose StatementEnd
