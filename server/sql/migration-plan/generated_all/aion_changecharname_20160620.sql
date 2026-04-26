-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeCharName_20160620.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changecharname_20160620(_char_i_d INTEGER, _server_i_d INTEGER, _item_id BIGINT, _item_tid BIGINT, _account TEXT, _old_name TEXT, _new_name TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- 유효한 이름인지 검사

declare _check_valid_char_name int

exec _check_valid_char_name = aion_CheckValidCharName

 _name = _new_name,

 _account = _account



if _check_valid_char_name <> 0

	return _check_valid_char_name





declare _ret int

_ret := _char_i_d



declare _change_log_id int

_change_log_id := 0



insert into user_name_change_log (char_id, old_name, new_name, change_date, item_id, tid,

				account_id, account_name, race, class, gender, lev)

select _char_i_d, _old_name, _new_name, NOW(), _item_id, _item_tid, 

				account_id, account_name, race, class, gender, lev

from user_data

where char_id = _char_i_d



if @_error <> 0 or @_rowcount = 0

begin 

	_ret := -4

	GOTO error_process

end



_change_log_id := @_i_d_e_n_t_i_t_y





declare _forbidden_id int

_forbidden_id := 0



-- 캐릭터 이름을 다른 사람이 다시 사용하지 못 하도록 forbidden_char에 추가

insert into forbidden_char (

			FORBIDDEN_TYPE, FORBIDDEN_REASON, WORLD_ID,

			FORBIDDEN_CHAR, FORBIDDEN_ACCOUNT_NM,

			STATUS, LOGIN_ID, LOGIN_NM, REGDATE)

values(1, 4, _server_i_d, _old_name, _account, 0, 'UseItem', 'ChangeCharName', NOW())



if @_error <> 0	or @_rowcount = 0

begin 

	_ret := -5	-- Forbidden_char Insert Error!!!

	GOTO error_process

end



_forbidden_id := @_i_d_e_n_t_i_t_y



UPDATE user_data

SET 	user_id = _new_name, change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE char_id  =  _char_i_d






IF @_e_r_r_o_r <> 0

begin 

	_ret := -6	-- Forbidden_char Insert Error!!!

	GOTO error_process

end



return _char_i_d



error_process:

if _change_log_id <> 0

begin

	DELETE FROM user_name_change_log where id = _change_log_id

end



if _forbidden_id <> 0

begin

	DELETE FROM forbidden_char where forbidden_id = _forbidden_id

end

return _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changecharname_20160620;
-- +goose StatementEnd
