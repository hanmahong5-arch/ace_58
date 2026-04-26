-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemFreeTradeState.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemfreetradestate(_itemid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _count int

SELECT COUNT(id) INTO _count from user_item_freeTrade (nolock) where id = _itemid



if _count >0 

begin

	select	freetradestate 

	from	user_item_freetrade (nolock)

	where	id = _itemid

end

else

	select 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemfreetradestate;
-- +goose StatementEnd
