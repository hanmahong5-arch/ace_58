-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemPolishPointList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitempolishpointlist(_char_id INTEGER, _warehouse_type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	user_item_polish.id, user_item_polish.name_id, user_item_polish.random_id, user_item_polish.polish_point

from	user_item_polish with(index(PK_user_item_polish), nolock) 

join	user_item with (nolock)

		on user_item_polish.id = user_item.id

where	user_item.char_id = _char_id AND

		user_item.warehouse = _warehouse_type;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitempolishpointlist;
-- +goose StatementEnd
