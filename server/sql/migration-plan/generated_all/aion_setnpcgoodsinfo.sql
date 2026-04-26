-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetNpcGoodsInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setnpcgoodsinfo(_world_no INTEGER, _merchant_nameid INTEGER, _goods_list_no INTEGER, _goods_nameid INTEGER, _sold_count BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select world_no from npc_goods_info(UPDLOCK) where world_no=_world_no and merchant_nameid=_merchant_nameid and goods_list_no=_goods_list_no and goods_nameid=_goods_nameid) 

	begin

		update npc_goods_info set sold_count=_sold_count where world_no=_world_no and merchant_nameid=_merchant_nameid and goods_list_no=_goods_list_no	and goods_nameid=_goods_nameid

	end

else 

	begin

		insert npc_goods_info(world_no, merchant_nameid, goods_list_no, goods_nameid, sold_count) values	(_world_no, _merchant_nameid, _goods_list_no, _goods_nameid, _sold_count)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setnpcgoodsinfo;
-- +goose StatementEnd
