-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemListCompoundedTwoHand.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemlistcompoundedtwohand(_char_id INTEGER, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



SELECT   a.id, a.name_id, a.main_item_dbid,

	COALESCE(b.stat_enchant_name0, 0),

	COALESCE(b.stat_enchant_name1, 0),

	COALESCE(b.stat_enchant_name2, 0),

	COALESCE(b.stat_enchant_name3, 0),

	COALESCE(b.stat_enchant_name4, 0),

	COALESCE(b.stat_enchant_name5, 0),

	COALESCE(b.option_count, 0), COALESCE(b.random_option, 0) AS random_option	

FROM user_item a, user_item_option b

WHERE a.char_id = _char_id and a.id = b.id AND a.warehouse = _warehouse;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlistcompoundedtwohand;
-- +goose StatementEnd
