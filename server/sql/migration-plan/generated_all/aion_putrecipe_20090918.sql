-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutRecipe_20090918.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putrecipe_20090918(_char_id INTEGER, _recipe_id INTEGER, _remain_count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_recipe(char_id, recipe_id, remain_count)

VALUES (_char_id, _recipe_id, _remain_count);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putrecipe_20090918;
-- +goose StatementEnd
