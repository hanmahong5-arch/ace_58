-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_loadlimitedsales.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlimitedsales(_npcid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT total_stock, check_time, item_id, cur_stock, limit_buy, limit_num, turn_count from npc_limited_sales where npc_id = _npcid and delete_flag = 0

END





/****** Object:  StoredProcedure aion_loadusersaleslog    Script Date: 08/14/2013 14:33:36 ******/

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlimitedsales;
-- +goose StatementEnd
