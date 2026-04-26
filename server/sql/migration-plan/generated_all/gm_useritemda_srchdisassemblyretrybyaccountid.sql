-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchDisassemblyRetryByAccountId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchdisassemblyretrybyaccountid(_account_id INTEGER, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	

	SELECT	charId, ItemId, retryCount, isDelete

			, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate

	FROM	user_item (nolock) u

	JOIN	user_disassembly_retry (nolock) d ON u.id = d.ItemId

	WHERE	u.char_id = _account_id AND u.warehouse = _warehouse;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchdisassemblyretrybyaccountid;
-- +goose StatementEnd
