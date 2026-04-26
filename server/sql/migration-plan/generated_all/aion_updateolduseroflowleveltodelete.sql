-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateOldUserOfLowlevelToDelete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updateolduseroflowleveltodelete(_check_days INTEGER, _low_level INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql


BEGIN

	IF EXISTS (SELECT object_id FROM sys.tables WHERE name = 'temp_user_id_object_to_del$')

		DROP TABLE temp_user_id_object_to_del$



	BEGIN TRAN



	DECLARE		_sql		nvarchar(4000)

	_sql := 'SELECT char_id INTO temp_user_id_object_to_del$ FROM user_data WHERE delete_date = 0 AND delete_complete_date = 0 AND GetUnixtimeWithUTCAdjust(last_logout_time, 0) + ' + CAST((3600*24*_check_days) AS nvarchar(20)) + '< GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) AND lev < ' + CAST(_low_level AS nvarchar(20)) 
RAISE NOTICE '%', _sql;

	EXEC sp_executesql _sql



	UPDATE user_data SET delete_date = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0), delete_complete_date = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) where char_id in (select char_id from temp_user_id_object_to_del$)



	COMMIT TRAN



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updateolduseroflowleveltodelete;
-- +goose StatementEnd
