-- AionCore 5.8 — Sprint 1.1a batch 17 port: aion_PutRecipe_20090918 (recipe-acquisition INSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutRecipe_20090918.sql
-- Original (T-SQL):
--   INSERT user_recipe(char_id, recipe_id, remain_count)
--   VALUES (@nCharId, @nRecipeId, @ucRemainCount)
--
-- Translation notes:
--   * NCSoft kept the date suffix `_20090918` from the legacy 2009 schema
--     migration. We expose the stable PG name `aion_putrecipe` (pattern
--     established by 00165 GetRecipeList — the opcode-binding layer can
--     alias the original date-suffixed name if needed).
--   * Parameter widths verified against NCSoft schema:
--       @nCharId        INT      → INTEGER
--       @nRecipeId      INT      → INTEGER
--       @ucRemainCount  TINYINT  → SMALLINT
--     The SMALLINT widening for remain_count matches the column type set in
--     00165 (NCSoft TINYINT is unsigned 0..255; PG has no unsigned tiny, so
--     SMALLINT covers the range without truncation. The Get path already
--     selects SMALLINT, so widths line up end-to-end).
--   * Pure INSERT — no upsert, no existence check. NCSoft relies on the
--     caller (cm_recipe_book / craft success path) to never insert a
--     duplicate. We mirror that contract: a duplicate (char_id, recipe_id)
--     will trip the PK in 00165 and bubble a duplicate_key error. That IS
--     the NCSoft behaviour (PK violation in T-SQL likewise raises 2627).
--   * Returns rows-affected (always 1 on success). Lets the Lua caller
--     distinguish "function ran, row landed" from a transport-level error.
--   * Function declared VOLATILE (data-modifying).
--
-- Bug-for-bug:
--   * No FK on user_recipe.char_id → user_data.char_id (NCSoft has none).
--     A recipe row can outlive its character — pinned (forensic property).
--   * No remain_count clamp. NCSoft accepts 0 (consumed/expired) and any
--     value up to TINYINT max 255. PG SMALLINT permits up to 32767, so we
--     are wider than NCSoft on that side; in the realistic TINYINT input
--     domain we are byte-equivalent.
--   * No tombstone / no soft-delete. The 00221 RemoveRecipe purges hard.
--
-- Used by:
--   scripts/handlers/cm_recipe_register.lua  (player learns a recipe)
--   scripts/lib/recipe.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putrecipe(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putrecipe(
    _char_id      INTEGER,
    _recipe_id    INTEGER,
    _remain_count SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure INSERT, mirroring NCSoft. Duplicate PK (char_id, recipe_id) will
    -- raise unique_violation by design — that IS the NCSoft contract.
    INSERT INTO user_recipe (char_id, recipe_id, remain_count)
    VALUES (_char_id, _recipe_id, _remain_count);
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putrecipe(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd
