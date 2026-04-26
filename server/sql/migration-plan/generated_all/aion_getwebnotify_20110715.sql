-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getwebnotify_20110715.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getwebnotify_20110715(_charid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    declare _count int

	select category, unsent, msg from user_webnotify with (nolock) where char_id = _charid	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwebnotify_20110715;
-- +goose StatementEnd
