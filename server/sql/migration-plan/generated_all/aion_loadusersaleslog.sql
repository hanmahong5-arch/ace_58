-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_loadusersaleslog.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadusersaleslog(_npcid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT item_id, char_id, purchase_time, COUNT, turn_count from npc_user_sales_log where npc_id = _npcid and delete_flag = 0 order by npc_id, item_id, char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadusersaleslog;
-- +goose StatementEnd
