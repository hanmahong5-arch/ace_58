-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CheckValidCharName.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkvalidcharname(_name TEXT, _account TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- 2016년 7월 6일 09시 기준

-- 이름변경시 유지 1년 -> 60일

declare _apply_date datetime = Cast('2016-07-06 09:00:00' as datetime)



-- 존재하는 이름 검사

IF EXISTS (SELECT char_id FROM user_data WHERE user_id=_name AND (delete_date = 0 OR (delete_date > GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0))))

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

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD = _name and IS_LIKE = 0 and status=0 and (forbidden_type=0 or forbidden_type=1))

	return -2	-- 금지 단어, GM 캐릭터



--IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD LIKE '%'+_name+'%' and IS_LIKE = 1 and status=0 and (forbidden_type=1 or forbidden_type=0)) 

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE (_name LIKE '%' + FORBIDDEN_WORD + '%') and forbidden_word <> '' and IS_LIKE = 1 and status=0 and (forbidden_type=1 or forbidden_type=0))

	return -2	-- 금지어 포함



-- IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_name and status=0 and (forbidden_reason in (3,4)) and (datediff(d, regdate, NOW()) < 366))

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_name and status=0 and (forbidden_reason in (3,4))

	and ((REGDATE < _apply_date and datediff(d, regdate, NOW()) < 366) or (datediff(d, regdate, NOW()) < 61)))

	return -2	-- 서버 이전이나, 캐릭터 이름 변경으로 1년간 사용 금지



-- 사전 예약

IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_name and status=0 and forbidden_reason = 2)

	BEGIN

		IF NOT EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=_name and FORBIDDEN_ACCOUNT_NM=_account and status=0 and forbidden_reason = 2)

			return -3

	END



return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkvalidcharname;
-- +goose StatementEnd
