-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_savelimitedsales.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_savelimitedsales(_npcid BIGINT, _checktime BIGINT, _totalstock INTEGER, _itemid BIGINT, _curstock INTEGER, _limitbuy INTEGER, _limitnum INTEGER, _turncnt INTEGER, _charid BIGINT, _count BIGINT, _purchasetime BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    update npc_limited_sales set cur_stock = _curstock, limit_buy = _limitbuy, limit_num = _limitnum, turn_count = _turncnt where npc_id = _npcid and item_id=_itemid and delete_flag = 0

    

    if @_r_o_w_c_o_u_n_t = 0

		insert into npc_limited_sales (npc_id, check_time, total_stock, item_id, cur_stock, limit_buy, limit_num, turn_count) values(_npcid, _checktime, _totalstock, _itemid, _curstock, _limitbuy, _limitnum, _turncnt)

	

	update npc_limited_sales set check_time=_checktime, total_stock=_totalstock where npc_id = _npcid and delete_flag = 0

	

	update npc_user_sales_log set purchase_time=_purchasetime, turn_count = _turncnt, count=_count where npc_id=_npcid and item_id = _itemid and char_id=_charid and delete_flag = 0

	

	if @_r_o_w_c_o_u_n_t = 0

		insert into npc_user_sales_log (npc_id, item_id, char_id, purchase_time, count, turn_count) values (_npcid, _itemid, _charid, _purchasetime, _count, _turncnt)

	

END



/****** Object:  StoredProcedure aion_clearlimitedsales    Script Date: 08/14/2013 14:31:55 ******/

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_savelimitedsales;
-- +goose StatementEnd
