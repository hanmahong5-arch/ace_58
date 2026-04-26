-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetBlockIdList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getblockidlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


    -- Insert statements for procedure here

	SELECT block_id FROM user_block WHERE char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblockidlist;
-- +goose StatementEnd
