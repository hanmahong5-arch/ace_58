-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_StartServer.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_startserver(_server_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _server_start_time int

declare _server_start_date_time datetime;

declare _server_end_date_time datetime;



if exists (select server_id from server_info(updlock) where server_id = _server_id and info_name = 'SERVER_START_TIME')

begin

_server_start_date_time := (select 

		dateadd(second, int_value - GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0), NOW())

		from server_info 

		where server_id = _server_id and info_name = 'SERVER_START_TIME')



_server_end_date_time := (select

		dateadd(second, int_value - GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0), NOW())

		from server_info 

		where server_id = _server_id and info_name = 'SERVER_LAST_HEARTBIT_TIME')



/*

 Login 처리 되어 있는 사용자 모두 Logout

*/

UPDATE user_data 

SET  last_logout_time = _server_end_date_time, playtime = playtime + datediff(minute,last_login_time,_server_end_date_time )

WHERE

cur_server = _server_id

and

last_login_time >= _server_start_date_time

and

last_login_time = last_logout_time



/*

 Start Time & Last Heartbit Update

*/

update server_info

Set int_value= GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0)

where

server_id = _server_id

and info_name = 'SERVER_START_TIME'



update server_info

Set int_value= GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0)

where

server_id = _server_id

and info_name = 'SERVER_LAST_HEARTBIT_TIME'

end

else

begin

/*

Data 가 없는 경우 초기화

*/

insert server_info

(server_id, info_name, int_value, int64_value, str_value)

Values(_server_id, 'SERVER_START_TIME', GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0), 0, '')



insert server_info

(server_id, info_name, int_value, int64_value, str_value)

Values(_server_id, 'SERVER_LAST_HEARTBIT_TIME', GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0), 0, '')



end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_startserver;
-- +goose StatementEnd
