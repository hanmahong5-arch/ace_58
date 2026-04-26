-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutCharChangeLog.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcharchangelog(_char_id INTEGER, _type INTEGER, _old_value INTEGER, _new_value INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _user_last_logintime datetime

declare _user_play_time int

declare _user_race tinyint

declare _user_class tinyint

declare _user_lev tinyint

SELECT race, _user_class = class, _user_lev = lev, _user_play_time = playtime, _user_last_logintime = last_login_time INTO _user_race from user_data  WHERE char_id = _char_id



declare _interval_time int

_interval_time := (SELECT playtime from user_change_log where char_id = _char_id and change_type = _type order by change_time desc)

if (_interval_time is null)

begin

	_interval_time := 0

end



insert user_change_log (char_id, change_type, race, class, lev, old_value, new_value, change_time, playtime, intervaltime)

VALUES (_char_id, _type, _user_race, _user_class, _user_lev, _old_value, _new_value, NOW(), _user_play_time + datediff(minute,_user_last_logintime,NOW()), _user_play_time + datediff(minute,_user_last_logintime,NOW()) - _interval_time)


 /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcharchangelog;
-- +goose StatementEnd
