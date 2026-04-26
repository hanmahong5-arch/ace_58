-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeGuildName_20090423.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changeguildname_20090423(_char_i_d INTEGER, _guild_id INTEGER, _server_id INTEGER, _item_id BIGINT, _item_tid BIGINT, _old_guild_name TEXT, _new_guild_name TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- 중복길드명

IF EXISTS (SELECT id FROM guild WHERE name = _new_guild_name)

	return -1



-- 길드 + 공통 금지어

--IF EXISTS (select forbidden_id from forbidden_word where FORBIDDEN_WORD=_guild_name and status=0 and forbidden_reason=1 and (forbidden_type=2 or forbidden_type=0)) 

--	return 0



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



-- 금지단어

IF EXISTS (SELECT forbidden_id FROM forbidden_word WHERE FORBIDDEN_WORD = _new_guild_name and IS_LIKE = 0 and status=0 and forbidden_type=0)

	return -2



-- 금지길드명

IF EXISTS (SELECT forbidden_id FROM forbidden_word WHERE FORBIDDEN_WORD = _new_guild_name and IS_LIKE = 0 and status=0 and forbidden_type=2 and forbidden_reason <> 5)

	return -2



-- 길드 이름 변경으로 1년간 사용 금지 길드명

IF EXISTS (SELECT forbidden_id FROM forbidden_word WHERE FORBIDDEN_WORD = _new_guild_name and IS_LIKE = 0 and status=0 and forbidden_type=2 and forbidden_reason = 5 and (datediff(d, regdate, NOW()) < 366))

	return -2



-- 금지단어가 포함된 길드명

IF EXISTS (SELECT forbidden_id FROM forbidden_word WHERE (_new_guild_name LIKE '%' + FORBIDDEN_WORD + '%')  and forbidden_word <> '' and IS_LIKE = 1 and status=0 and (forbidden_type=2 or forbidden_type=0))

	return -2



declare _ret int

_ret := _guild_id



declare _change_log_id int

_change_log_id := 0



insert into guild_name_change_log (guild_id, old_name, new_name, change_date, item_id, tid, 

								master_id, master_user_id, master_account_id, master_account_name, race, class, gender, lev)

select _guild_id, _old_guild_name, _new_guild_name, NOW(), _item_id, _item_tid, 

								char_id, user_id, account_id, account_name, race, class, gender, lev

from user_data

where char_id = _char_i_d



if @_error <> 0 or @_rowcount = 0

begin 

	_ret := -4

	GOTO error_process

end



declare _forbidden_id int

_forbidden_id := 0



-- 캐릭터 이름을 다른 사람이 다시 사용하지 못 하도록 forbidden_char에 추가

insert into forbidden_word (

			FORBIDDEN_TYPE, FORBIDDEN_REASON, WORLD_ID,

			FORBIDDEN_WORD,

			STATUS, LOGIN_ID, LOGIN_NM, REGDATE, IS_LIKE)

values(2, 5, _server_id, _old_guild_name, 0, 'UseItem', 'ChangeGuildName', NOW(), 0)



if @_error <> 0	or @_rowcount = 0

begin 

	_ret := -5	-- Forbidden_char Insert Error!!!

	GOTO error_process

end



UPDATE guild 

SET name = _new_guild_name, change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE id = _guild_id




IF @_e_r_r_o_r <> 0

begin 

	_ret := -6

	GOTO error_process

end



return _guild_id



error_process:

if _change_log_id <> 0

begin

	DELETE FROM guild_name_change_log where id = _change_log_id

end



if _forbidden_id <> 0

begin

	DELETE FROM forbidden_word where forbidden_id = _forbidden_id

end

return _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changeguildname_20090423;
-- +goose StatementEnd
