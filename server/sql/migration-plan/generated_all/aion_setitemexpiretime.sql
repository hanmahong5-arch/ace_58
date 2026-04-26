-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_setItemExpireTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemexpiretime(_id BIGINT, _expire_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    update user_item set expired_time = _expire_time where id = _id

	-- and expired_time=0 // 기간제속성변경때문에 제거

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemexpiretime;
-- +goose StatementEnd
