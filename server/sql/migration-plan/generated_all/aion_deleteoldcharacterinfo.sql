-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_deleteoldcharacterinfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteoldcharacterinfo(_charid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	update user_old_character set delete_flag = 1 where char_id = _charid and delete_flag=0

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteoldcharacterinfo;
-- +goose StatementEnd
