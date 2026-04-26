-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLogoutTime_20120516.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlogouttime_20120516(_char_id INTEGER, _logout_time TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _curr_time datetime

_curr_time := NOW()

_logout_time := convert(nvarchar(30), _curr_time, 126) 



UPDATE user_data 

SET last_logout_time = _curr_time , playtime = playtime + datediff(minute,last_login_time,_curr_time),

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)  

WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlogouttime_20120516;
-- +goose StatementEnd
