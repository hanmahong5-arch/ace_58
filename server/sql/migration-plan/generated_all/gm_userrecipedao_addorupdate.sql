-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRecipeDAO_AddorUpdate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrecipedao_addorupdate(_char_id TEXT, _recipe_id TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if not EXISTS (SELECT char_id FROM user_recipe WHERE char_id=_char_id and recipe_id=_recipe_id ) 

		begin

			INSERT into user_recipe(char_id, recipe_id) VALUES (_char_id, _recipe_id)

		end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrecipedao_addorupdate;
-- +goose StatementEnd
