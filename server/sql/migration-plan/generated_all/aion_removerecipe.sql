-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveRecipe.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removerecipe(_user_id INTEGER, _recipe_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_recipe

WHERE char_id = _user_id AND recipe_id = _recipe_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removerecipe;
-- +goose StatementEnd
