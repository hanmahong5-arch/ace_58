-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteUserInstanceByServerId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteuserinstancebyserverid(_server_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DELETE FROM user_instance WHERE server_id = _server_id and world_id NOT IN (302350000, 302450000, 300360000, 302320000, 302390000, 300450000)

END



/****** Object:  StoredProcedure aion_InitInstanceCooltime_170817    Script Date: 02/21/2018 20:18:18 ******/

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteuserinstancebyserverid;
-- +goose StatementEnd
