-- AionCore 5.8 — Sprint 1.1a batch 21 port: aion_SetCharWarehouseGrowth
-- (single-column UPDATE — char_warehouse_growth tier).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharWarehouseGrowth.sql
-- Original (T-SQL):
--   UPDATE user_data
--   SET char_warehouse_growth = @cGrowth
--   WHERE char_id = @nCharId
--
-- Translation notes:
--   * char_warehouse_growth is the *per-character* warehouse expansion
--     tier (distinct from acc_warehouse_growth which is account-level
--     and not yet ported). The character's personal warehouse window
--     widens by a class-independent delta per tier. Pinned.
--   * Sibling pattern with 00239/00240/00242 — same control flow,
--     different column. See batch rationale in 00239.
--   * Silent no-op on missing char_id. Pinned.
--   * @cGrowth is TINYINT (0-255) → SMALLINT in PG. PG column added in
--     00032 round-3 (SMALLINT NOT NULL DEFAULT 0).
--   * VOLATILE. RETURNS VOID.
--
-- Bug-for-bug:
--   * NO upper-bound CHECK; NCSoft enforces tier cap client-side.
--   * NO delete_date / banned guard.
--   * Last-writer-wins on concurrent calls.
--   * acc_warehouse_growth is a *separate* SP (not yet ported) —
--     do NOT cross-write here even though both columns relate to
--     "warehouse capacity"; T-SQL keeps them strictly partitioned.
--
-- Used by:
--   scripts/handlers/cm_warehouse_expand.lua   -- consume warehouse-expand item
--   scripts/lib/warehouse.lua                  -- shared warehouse hook

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharwarehousegrowth(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : owning user_data.char_id
-- _growth  : new tier (TINYINT 0-255 in T-SQL → SMALLINT in PG)
CREATE OR REPLACE FUNCTION aion_setcharwarehousegrowth(
    _char_id INTEGER,
    _growth  SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET char_warehouse_growth = _growth
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharwarehousegrowth(INTEGER, SMALLINT);
-- +goose StatementEnd
