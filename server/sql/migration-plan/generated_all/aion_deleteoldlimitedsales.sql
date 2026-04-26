-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_deleteOldlimitedsales.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteoldlimitedsales()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	delete from npc_limited_sales where delete_flag = 1 and DATEDIFF(day, createtime, NOW()) > 30

	delete from npc_user_sales_log where delete_flag = 1 and DATEDIFF(day, createtime, NOW()) > 30

END





-- ================================================

-- Template generated from Template Explorer using:

-- Create Procedure (New Menu).SQL

--

-- Use the Specify Values for Template Parameters 

-- command (Ctrl-Shift-M) to fill in the parameter 

-- values below.

--

-- This block of comments will not be included in

-- the definition of the procedure.

-- ================================================

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteoldlimitedsales;
-- +goose StatementEnd
