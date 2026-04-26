-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemChargePointListAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemchargepointlistall(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	user_item_charge.id, user_item_charge.charge_point

from	user_item_charge with(nolock) 

join	user_item with (nolock)

		on user_item_charge.id = user_item.id

where	user_item.char_id = _char_id and

		user_item.warehouse != 10

		option(loop join);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemchargepointlistall;
-- +goose StatementEnd
