-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetRecipeList_20090918.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getrecipelist_20090918(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT recipe_id, remain_count

FROM user_recipe

WHERE char_id=_char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getrecipelist_20090918;
-- +goose StatementEnd
