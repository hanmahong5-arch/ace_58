-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_clearlimitedsales.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearlimitedsales(_npcid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	update npc_limited_sales set delete_flag = 1 where npc_Id = _npcid and delete_flag=0

	update npc_user_sales_log set delete_flag = 1 where npc_Id = _npcid and delete_flag=0    

END



/****** Object:  StoredProcedure aion_loadlimitedsales    Script Date: 08/14/2013 14:33:16 ******/

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearlimitedsales;
-- +goose StatementEnd
