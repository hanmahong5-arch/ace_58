-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchMyItemPolishAccount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyitempolishaccount(_account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select t2.id, t2.name_id, t2.random_id, t2.polish_point

			from user_item t1(nolock), user_item_polish t2(nolock)

			where t1.char_id = _account_id

			and t1.id = t2.id

			and t1.warehouse IN (6,7);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchmyitempolishaccount;
-- +goose StatementEnd
