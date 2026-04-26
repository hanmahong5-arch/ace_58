-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeCharName_20090423.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changecharname_20090423(_char_i_d INTEGER, _server_i_d INTEGER, _item_id BIGINT, _item_tid BIGINT, _account TEXT, _old_name TEXT, _new_name TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- 존재하는 이름 검사

IF EXISTS (SELECT char_id FROM user_data WHERE user_id=_new_name AND (delete_date = 0 OR (delete_date > GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0))))

	return -1



-- 금지캐릭터명 + 공통 금지어

-- forbidden_type

-- 0 : 공통

-- 1 : 캐릭터

-- 2 : 길드

-- forbidden_reason

-- 0 : GM 캐릭터

-- 1 : 일반 금지어

-- 2 : 캐릭터 사전 예약

-- 3 : 서버 이전	(1년간 재사용 금지)

-- 4 : 아이템 캐릭터 이름 변경 (1년간 재사용 금지)

-- 5 : 아이템 길드 이름 변경 (1년간 재사용 금지)

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD = _new_name and IS_LIKE = 0 and status=0 and (forbidden_type=0 or forbidden_type=1))

	return -2	-- 금지 단어, GM 캐릭터



--IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD LIKE '%'+_name+'%' and IS_LIKE = 1 and status=0 and (forbidden_type=1 or forbidden_type=0)) 

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE (_new_name LIKE '%' + FORBIDDEN_WORD + '%') and forbidden_word <> '' and IS_LIKE = 1 and status=0 and (forbidden_type=1 or forbidden_type=0))

	return -2	-- 금지어 포함





IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_new_name and status=0 and (forbidden_reason in (3,4)) and (datediff(d, regdate, NOW()) < 366))

	return -2	-- 서버 이전이나, 캐릭터 이름 변경으로 1년간 사용 금지



-- 사전 예약

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_new_name and status=0 and forbidden_reason = 2)

	BEGIN

		IF NOT EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_new_name and FORBIDDEN_ACCOUNT_NM=_account and status=0 and forbidden_reason = 2)

			return -2

	END



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
DROP FUNCTION IF EXISTS aion_changecharname_20090423;
-- +goose StatementEnd
