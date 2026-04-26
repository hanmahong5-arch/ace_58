-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemPolishPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitempolishpoint(_dbid BIGINT, _count INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    if _count = 0

		DELETE FROM user_item_polish where id =_dbid

    else

		update user_item_polish set polish_point = _count where id = _dbid



	/*

	if EXISTS (SELECT id FROM user_item_polish (UPDLOCK) WHERE id=_dbid) 

	begin

		if _count = 0

			DELETE FROM user_item_polish where id =_dbid

		else

			update user_item_polish set polish_point = _count where id = _dbid

	end

	*/

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitempolishpoint;
-- +goose StatementEnd
