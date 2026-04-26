-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetWardrobe.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getwardrobe(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT slot_id, name_id FROM user_wardrobe WITH(NOLOCK) WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwardrobe;
-- +goose StatementEnd
