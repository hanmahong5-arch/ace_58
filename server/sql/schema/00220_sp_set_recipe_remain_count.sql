-- AionCore 5.8 — Sprint 1.1a batch 17 port: aion_SetRecipeRemainCount (recipe charge UPDATE).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetRecipeRemainCount.sql
-- Original (T-SQL):
--   UPDATE user_recipe
--   SET remain_count = @ucRemainCount
--   WHERE char_id=@nCharId and recipe_id = @nRecipeId
--
-- Translation notes:
--   * Sister of 00219 PutRecipe. Decrements (or sets) the remain_count
--     charge on a learned recipe — typically called after a craft consumes
--     one charge from a limited-charge recipe.
--   * Pure UPDATE (no upsert). If the (char_id, recipe_id) row does not
--     exist, the call is a NO-OP and returns 0 rows affected. The Lua
--     caller MUST treat 0 as "recipe not learned" rather than as success.
--     This mirrors NCSoft @@ROWCOUNT semantics exactly (T-SQL UPDATE on
--     non-existent row returns rowcount 0, no error).
--   * Parameter widths verified against NCSoft schema:
--       @nCharId        INT      → INTEGER
--       @nRecipeId      INT      → INTEGER
--       @ucRemainCount  TINYINT  → SMALLINT
--     SMALLINT widening matches 00165 / 00219 column type.
--   * Returns rows-affected (1 on success / 0 if no row). Lets the Lua
--     caller branch on whether the recipe exists.
--
-- Bug-for-bug:
--   * No clamp on remain_count. NCSoft accepts 0 (recipe consumed; 5.8
--     client treats 0 as expired) and any TINYINT value 0..255. We accept
--     SMALLINT 0..32767 — wider on the high end, byte-equivalent in the
--     realistic input domain.
--   * Setting remain_count to 0 does NOT auto-delete the row (the 00221
--     RemoveRecipe SP is the explicit hard-delete path). Pinned verbatim.
--   * No FK on user_recipe.char_id. Orphan-tolerant.
--
-- Used by:
--   scripts/handlers/cm_craft_complete.lua  (consume one recipe charge)
--   scripts/lib/recipe.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setreciperemaincount(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setreciperemaincount(
    _char_id      INTEGER,
    _recipe_id    INTEGER,
    _remain_count SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure UPDATE on PK (char_id, recipe_id). Returns 0 rows affected if
    -- the recipe was never learned — caller decides how to react.
    UPDATE user_recipe
       SET remain_count = _remain_count
     WHERE char_id   = _char_id
       AND recipe_id = _recipe_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setreciperemaincount(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd
