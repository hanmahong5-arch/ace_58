-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteUserUsedItemOnTradingByDate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteuseruseditemontradingbydate(_date INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	-- 등록 후 (_date)일이 지난 데이타 삭제

	DELETE	

	FROM	user_useditem_ontrading

	WHERE	regdate < dateadd(day, -_date, NOW())




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteuseruseditemontradingbydate;
-- +goose StatementEnd
