-- AionCore 5.8 — Sprint 1.1a batch 21 port: aion_SetCashItemInventoryGrowth
-- (single-column UPDATE — cashitem_inventory_growth tier).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCashItemInventoryGrowth.sql
-- Original (T-SQL):
--   UPDATE user_data
--   SET cashitem_inventory_growth = @cGrowth
--   WHERE char_id = @nCharId
--
-- Translation notes:
--   * cashitem_inventory_growth is the *cash-shop* (paid) inventory
--     expansion tier. Distinct from inventory_growth (00239) because
--     NCSoft tracks free-tier vs paid-tier separately for refund /
--     chargeback flows: a paid tier can be revoked without nuking the
--     base tier. Pinned.
--   * Identical control flow to siblings 00239/00241/00242 — only the
--     target column differs. Kept as a separate SP, see batch-mate
--     rationale in 00239 ("audit pipeline keys on SP name, not column").
--   * Silent no-op on missing char_id. Pinned.
--   * @cGrowth is TINYINT (0-255) → SMALLINT in PG. PG column added in
--     00032 round-3 (SMALLINT NOT NULL DEFAULT 0).
--   * VOLATILE. RETURNS VOID.
--
-- Bug-for-bug:
--   * NO upper-bound CHECK; NCSoft enforces tier cap client-side.
--   * NO delete_date / banned guard. Refund flow assumes upstream caller
--     has resolved the user's account state before invoking this SP.
--   * Last-writer-wins on concurrent calls.
--
-- Used by:
--   scripts/handlers/cm_cash_inventory_expand.lua   -- cash-shop redemption
--   scripts/lib/shop.lua                            -- shared cash-shop hook

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcashiteminventorygrowth(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : owning user_data.char_id
-- _growth  : new tier (TINYINT 0-255 in T-SQL → SMALLINT in PG)
CREATE OR REPLACE FUNCTION aion_setcashiteminventorygrowth(
    _char_id INTEGER,
    _growth  SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET cashitem_inventory_growth = _growth
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcashiteminventorygrowth(INTEGER, SMALLINT);
-- +goose StatementEnd
