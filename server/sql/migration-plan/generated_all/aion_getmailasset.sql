-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetMailAsset.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmailasset(_character_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- BEGIN OF QUERY

	SELECT ui.name_id, money FROM user_mail AS um(nolock) LEFT OUTER JOIN user_item AS ui(nolock) ON ui.id = um.item_id WHERE um.to_id = _character_id AND (um.item_id <> 0 OR um.money <> 0)

-- END OF QUERY;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmailasset;
-- +goose StatementEnd
