-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorAsset.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendorasset(_character_id INTEGER, _race INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- BEGIN OF QUERY

	IF (_race = 0)

		SELECT ui.name_id FROM user_item AS ui(nolock) INNER JOIN vendor_item_light AS vl(nolock) ON ui.id = vl.user_item_id WHERE vl.char_id = _character_id

	ELSE

		SELECT ui.name_id FROM user_item AS ui(nolock) INNER JOIN vendor_item_dark  AS vd(nolock) ON ui.id = vd.user_item_id WHERE vd.char_id = _character_id

-- END OF QUERY;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendorasset;
-- +goose StatementEnd
