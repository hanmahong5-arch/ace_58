-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchMyItemFreeTradeAccount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyitemfreetradeaccount(_account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select	f.id, f.name_id, f.freetradestate

			from	user_item i(nolock)

			join	user_item_freeTrade f(nolock) on f.id = i.id

			where	i.char_id = _account_id

			and		i.warehouse IN (6,7);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchmyitemfreetradeaccount;
-- +goose StatementEnd
