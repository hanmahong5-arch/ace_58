-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getItemListFreeTrade.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemlistfreetrade(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	user_item_freetrade.id, user_item_freetrade.freetradestate

from	user_item_freetrade with(index(PK_user_item_freetrade), nolock) 

join	user_item with (nolock)

		on user_item_freetrade.id = user_item.id

where	user_item.char_id = _char_id and

		user_item.warehouse != 10;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlistfreetrade;
-- +goose StatementEnd
