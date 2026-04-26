-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLoginTime_20120516.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlogintime_20120516(_char_id INTEGER, _server_id INTEGER, _login_time TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _char_name nvarchar(20)

DECLARE _guild_id int

DECLARE _account nvarchar(16)

DECLARE _account_no int

DECLARE _hardware nvarchar(16)

DECLARE _curr_time datetime



_curr_time := NOW()

_login_time := convert(nvarchar(30), _curr_time, 126) 



UPDATE user_data 

SET last_login_time = _curr_time, last_logout_time = _curr_time,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0),

	login_server = _server_id

WHERE char_id = _char_id





SELECT hardware INTO _hardware FROM AionAccountDB.AccountETC WHERE gameAccountNo = _account_no

UPDATE user_data SET hardware = _hardware WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlogintime_20120516;
-- +goose StatementEnd
