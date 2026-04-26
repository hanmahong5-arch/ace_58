-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CheckOldUserOfLowlevelToDelete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkolduseroflowleveltodelete(_check_days INTEGER, _low_level INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	DECLARE		_charcnt	int

	SELECT COUNT(*) INTO _charcnt FROM user_data WHERE delete_date = 0 AND delete_complete_date = 0 AND GetUnixtimeWithUTCAdjust(last_logout_time, 0) + 3600*24*_check_days < GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) AND lev < _low_level
RAISE NOTICE '%', 'applied char count : ' + CAST(_charcnt AS nvarchar(20));

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkolduseroflowleveltodelete;
-- +goose StatementEnd
