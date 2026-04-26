-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetBuddy_130319.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getbuddy_130319(_char_id INTEGER, _type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    DECLARE _utc_adjust BIGINT

    _utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())

    if _type = 0

    begin		-- 3 table join with ins house

		

		SELECT buddy_id, user_id, lev, class, gender, world, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust), b.delete_flag, d.daily_comment, d.race, 0, COALESCE(e.id, -1), COALESCE(permission,0), COALESCE(b.comment, N'') FROM user_buddy1 AS b INNER JOIN user_data AS d ON b.buddy_id=d.char_id left join house_instant as e on e.id = d.char_id  and e.state<>6 WHERE b.char_id = _char_id

	end

	else

	begin		-- 3 table join with field house

		

		SELECT buddy_id, user_id, lev, class, gender, world, GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust), b.delete_flag, d.daily_comment, d.race, e.id, e.addr_id, COALESCE(permission,0), COALESCE(b.comment, N'') FROM user_buddy1 AS b INNER JOIN user_data AS d ON b.buddy_id=d.char_id  inner join house_field as e on e.owner_id = d.char_id AND e.owner_type = 2 WHERE b.char_id = _char_id

	end

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbuddy_130319;
-- +goose StatementEnd
