-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_forbiddenlist.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_forbiddenlist(_type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- 2016년 7월 6일 09시 기준

-- 이름변경시 유지 1년 -> 60일

declare _apply_date datetime = Cast('2016-07-06 09:00:00' as datetime)




	if _type=1	

		select forbidden_word, forbidden_type*10+forbidden_reason as relate from forbidden_word with(nolock) where STATUS=0 and IS_LIKE=0

	if _type=2

		select forbidden_word, forbidden_type*10+forbidden_reason as relate from forbidden_word with(nolock) where STATUS=0 and IS_LIKE=1

	if _type=3

		select forbidden_char, forbidden_type*10+forbidden_reason as relate from forbidden_char with(nolock) where status=0 and (forbidden_reason in (3,4))

			and ((REGDATE < _apply_date and datediff(d, regdate, NOW()) < 366) or (datediff(d, regdate, NOW()) < 61));
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_forbiddenlist;
-- +goose StatementEnd
