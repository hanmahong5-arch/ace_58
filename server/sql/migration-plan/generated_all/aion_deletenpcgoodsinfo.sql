-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteNpcGoodsInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletenpcgoodsinfo(_world_no INTEGER, _merchant_nameid INTEGER, _goods_list_no INTEGER, _goods_nameid INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
delete from npc_goods_info where world_no=_world_no and merchant_nameid=_merchant_nameid and goods_list_no=_goods_list_no	and goods_nameid=_goods_nameid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletenpcgoodsinfo;
-- +goose StatementEnd
