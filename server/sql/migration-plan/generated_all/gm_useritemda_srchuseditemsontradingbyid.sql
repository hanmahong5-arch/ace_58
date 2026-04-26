-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchUsedItemsOnTradingById.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchuseditemsontradingbyid(_used_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



		SELECT	used_id, char_id, trade_type, tradeitemid, tradeitem_amount

				, useditem_nameid1, useditem_amount1, useditem_nameid2, useditem_amount2, useditem_nameid3, useditem_amount3

				, used_abysspoint, used_money, status, convert(nvarchar,regdate,20) regdate

				-- 4.71 진화확장

				, COALESCE(useditem_nameid4, 0) as useditem_nameid4, COALESCE(useditem_amount4, 0) as useditem_amount4

				, COALESCE(useditem_nameid5, 0) as useditem_nameid5, COALESCE(useditem_amount5, 0) as useditem_amount5

				, COALESCE(useditem_nameid6, 0) as useditem_nameid6, COALESCE(useditem_amount6, 0) as useditem_amount6

				, COALESCE(usedItem_dbid1, 0) as usedItem_dbid1, COALESCE(usedItem_dbid2, 0) as usedItem_dbid2, COALESCE(usedItem_dbid3, 0) as usedItem_dbid3

				, COALESCE(usedItem_dbid4, 0) as usedItem_dbid4, COALESCE(usedItem_dbid5, 0) as usedItem_dbid5, COALESCE(usedItem_dbid6, 0) as usedItem_dbid6

		FROM	user_useditem_ontrading (nolock)

		WHERE	used_id = _used_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchuseditemsontradingbyid;
-- +goose StatementEnd
