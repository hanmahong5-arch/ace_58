-- AionCore 5.8 — Sprint 1.1a batch 17 port: aion_RemoveRecipe (recipe DELETE).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_RemoveRecipe.sql
-- Original (T-SQL):
--   DELETE FROM user_recipe
--   WHERE char_id = @nUserId AND recipe_id = @nRecipeId
--
-- Translation notes:
--   * Hard-delete a single recipe entry (paired with 00219 PutRecipe).
--     Used when a recipe is forgotten / scrolled / GM-revoked.
--   * Pure DELETE. If the (char_id, recipe_id) row does not exist, the call
--     is a NO-OP and returns rows-affected = 0. NCSoft T-SQL behaves
--     identically (@@ROWCOUNT = 0, no error).
--   * NCSoft parameter is named `@nUserId` in the SP signature but binds to
--     the user_recipe.char_id column — naming inconsistency in the original.
--     We canonicalize to `_char_id` in the PG signature (clearer; matches
--     every other recipe SP). The opcode-binding layer wires the same value.
--   * Parameter widths:
--       @nUserId    INT  → INTEGER (binds to char_id)
--       @nRecipeId  INT  → INTEGER
--   * Returns rows-affected (1 on success / 0 if not learned).
--
-- Bug-for-bug:
--   * No cascade. user_recipe is the only table holding recipe state, so
--     there is nothing else to clean up — but if a future feature adds a
--     dependent table, that cleanup MUST be added explicitly here.
--   * No FK on user_recipe.char_id. Orphan-tolerant.
--   * The DELETE is unconditional — it will purge a recipe even with
--     remain_count > 0 (i.e. unused charges are forfeited). NCSoft's
--     "GM revoke" path relies on this; pinned.
--
-- Used by:
--   scripts/handlers/cm_recipe_forget.lua  (player forgets a recipe)
--   scripts/lib/recipe.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removerecipe(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removerecipe(
    _char_id   INTEGER,
    _recipe_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Hard-delete on PK (char_id, recipe_id). 0 rows affected if not learned.
    DELETE FROM user_recipe
     WHERE char_id   = _char_id
       AND recipe_id = _recipe_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removerecipe(INTEGER, INTEGER);
-- +goose StatementEnd
