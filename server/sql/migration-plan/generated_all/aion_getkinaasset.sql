-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetKinaAsset.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getkinaasset(_character_id INTEGER, _account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT warehouse, amount FROM user_item(nolock) WHERE char_id = _character_id and name_id = 182400001 and warehouse = 0

	UNION

	SELECT top 2 warehouse, amount FROM user_item(nolock) WHERE char_id = _account_id and name_id = 182400001 and (warehouse = 6 OR warehouse = 7)
 /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getkinaasset;
-- +goose StatementEnd
