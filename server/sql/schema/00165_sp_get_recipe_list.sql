-- AionCore 5.8 — Sprint 1.1a batch 6 port: aion_GetRecipeList (login recipe-book hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetRecipeList_20090918.sql
-- Original (T-SQL):
--   SELECT recipe_id, remain_count
--   FROM user_recipe
--   WHERE char_id=@nCharId
--
-- Translation notes:
--   * NCSoft kept the date suffix `_20090918` on the SP name from the legacy
--     2009 schema migration; the function name in PG drops it and uses the
--     stable form `aion_getrecipelist` so callers don't ride a frozen date.
--     The opcode-binding layer in Go will alias the original name if needed.
--   * Per-row state:
--       - recipe_id     INTEGER  : 5.8 recipe catalog id (cooking, smithing, …)
--       - remain_count  SMALLINT : uses left for limited-charge recipes
--                                  (-1 = unlimited; 0 = consumed/expired)
--   * No tombstone filter — NCSoft relies on remain_count semantics in client.
--     We preserve that contract: even rows with remain_count = 0 surface, the
--     client decides display.
--   * PRIMARY KEY (char_id, recipe_id) — a recipe is owned at most once.
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- recipe-book hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_recipe (
    char_id      INTEGER  NOT NULL,
    recipe_id    INTEGER  NOT NULL,
    remain_count SMALLINT NOT NULL DEFAULT -1,
    PRIMARY KEY (char_id, recipe_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_recipe_char ON user_recipe(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getrecipelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getrecipelist(_char_id INTEGER)
RETURNS TABLE (
    recipe_id    INTEGER,
    remain_count SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ur.recipe_id, ur.remain_count
          FROM user_recipe ur
         WHERE ur.char_id = _char_id
         ORDER BY ur.recipe_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getrecipelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_recipe_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_recipe;
-- +goose StatementEnd
