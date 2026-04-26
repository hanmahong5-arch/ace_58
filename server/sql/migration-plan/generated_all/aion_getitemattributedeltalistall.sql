-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getItemAttributeDeltaListAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemattributedeltalistall(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	user_item_attribute.id, 

		attribute1, attribute1value, 

		attribute2, attribute2value, 		

		attribute3, attribute3value, 

		attribute4, attribute4value, 

		attribute5, attribute5value, 

		attribute6, attribute6value

from	user_item_attribute with(index(PK_user_item_attribute), nolock) 

join	user_item with (nolock)

		on user_item_attribute.id = user_item.id

where	user_item.char_id = _char_id and

		user_item.warehouse != 10;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemattributedeltalistall;
-- +goose StatementEnd
