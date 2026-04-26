-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetNpcGoodsInfoList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getnpcgoodsinfolist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select world_no, merchant_nameid, goods_list_no, goods_nameid, sold_count from npc_goods_info;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getnpcgoodsinfolist;
-- +goose StatementEnd
