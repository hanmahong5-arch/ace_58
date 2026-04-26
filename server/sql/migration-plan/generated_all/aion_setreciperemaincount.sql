-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetRecipeRemainCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setreciperemaincount(_char_id INTEGER, _recipe_id INTEGER, _remain_count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_recipe

SET remain_count = _remain_count

WHERE char_id=_char_id and recipe_id = _recipe_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setreciperemaincount;
-- +goose StatementEnd
