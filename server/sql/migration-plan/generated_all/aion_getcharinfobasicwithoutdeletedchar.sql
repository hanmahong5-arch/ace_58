-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharInfoBasicWithoutDeletedChar.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharinfobasicwithoutdeletedchar(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT account_id FROM user_data WHERE char_id = _char_id AND (delete_date = 0 OR (delete_date > GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)))

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharinfobasicwithoutdeletedchar;
-- +goose StatementEnd
