-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDisassemblyRetryList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdisassemblyretrylist(_charid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select itemId, retryCount, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5 

	from user_disassembly_retry with (nolock)

	where charId = _charid and isDelete = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdisassemblyretrylist;
-- +goose StatementEnd
