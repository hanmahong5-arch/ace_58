-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetInventoryGrowth.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinventorygrowth(_char_id INTEGER, _growth INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data

SET inventory_growth = _growth

WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinventorygrowth;
-- +goose StatementEnd
