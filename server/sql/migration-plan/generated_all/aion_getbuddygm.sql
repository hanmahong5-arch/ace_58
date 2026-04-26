-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetBuddyGM.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getbuddygm(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DECLARE _utc_adjust BIGINT

	_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())

	SELECT buddy_id, user_id, lev, class, gender, world, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust), b.delete_flag, d.daily_comment FROM user_buddy1 AS b INNER JOIN user_data AS d ON b.buddy_id=d.char_id WHERE b.char_id = _char_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbuddygm;
-- +goose StatementEnd
