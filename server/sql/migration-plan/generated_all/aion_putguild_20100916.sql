-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutGuild_20100916.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putguild_20100916(_guild_name TEXT, _master_id INTEGER, _race INTEGER, _sub_master_right INTEGER, _officer_right INTEGER, _member_right INTEGER, _newbie_right INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- 중복길드명

IF EXISTS (SELECT id FROM guild WHERE name = _guild_name) 

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

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD = _guild_name and IS_LIKE = 0 and status=0 and forbidden_type=0)

	return -2



-- 금지길드명

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD = _guild_name and IS_LIKE = 0 and status=0 and forbidden_type=2 and forbidden_reason <> 5)

	return -2



-- 길드 이름 변경으로 1년간 사용 금지 길드명

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD = _guild_name and IS_LIKE = 0 and status=0 and forbidden_type=2 and forbidden_reason = 5 and (datediff(d, regdate, NOW()) < 366))

	return -2



-- 금지단어가 포함된 길드명

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE (_guild_name LIKE '%' + FORBIDDEN_WORD + '%')  and forbidden_word <> '' and IS_LIKE = 1 and status=0 and (forbidden_type=2 or forbidden_type=0))

	return -2

	

INSERT guild (name, race, master_id, level, rank, submaster_right, officer_right, member_right, newbie_right, point, fund, delete_requested, delete_time, notice1, notice2, notice3, notice4, notice5, notice6, notice7, change_info_time) 

VALUES (_guild_name, _race, _master_id, 1, 0, _sub_master_right, _officer_right, _member_right, _newbie_right, 0, 0, 0, 0, '', '', '', '', '', '', '', GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0))




IF @_e_r_r_o_r <> 0

	return 0



return @_i_d_e_n_t_i_t_y;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putguild_20100916;
-- +goose StatementEnd
