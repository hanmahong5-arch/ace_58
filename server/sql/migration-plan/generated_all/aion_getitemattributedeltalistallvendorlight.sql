-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemAttributeDeltaListAllVendorLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemattributedeltalistallvendorlight(_ownerid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if _ownerid = 0

	select	b.id, 

		b.attribute1, b.attribute1value, 

		b.attribute2, b.attribute2value, 		

		b.attribute3, b.attribute3value, 

		b.attribute4, b.attribute4value, 

		b.attribute5, b.attribute5value, 

		b.attribute6, b.attribute6value

from	user_item_attribute b with(index(PK_user_item_attribute), nolock) 

join	vendor_item_light a with (nolock)

		on b.id = a.user_item_id

	--select a.user_item_id, b.name_id, b.random_id, b.polish_point  from vendor_item_light a join user_item_polish b on a.user_item_id = b.id

else

	select	b.id, 

		b.attribute1, b.attribute1value, 

		b.attribute2, b.attribute2value, 		

		b.attribute3, b.attribute3value, 

		b.attribute4, b.attribute4value, 

		b.attribute5, b.attribute5value, 

		b.attribute6, b.attribute6value

from	user_item_attribute b with(index(PK_user_item_attribute), nolock) 

join	vendor_item_light a with (nolock)

		on b.id = a.user_item_id

where	a.char_id = _ownerid 

	--select a.user_item_id, a.user_item_id, b.name_id, b.random_id, b.polish_point from vendor_item_light a join user_item_polish b on (a.user_item_id = b.id and a.char_id = _ownerid);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemattributedeltalistallvendorlight;
-- +goose StatementEnd
