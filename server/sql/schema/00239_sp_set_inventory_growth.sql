-- AionCore 5.8 — Sprint 1.1a batch 21 port: aion_SetInventoryGrowth
-- (single-column UPDATE — bumps user_data.inventory_growth slot tier).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInventoryGrowth.sql
-- Original (T-SQL):
--   UPDATE user_data
--   SET inventory_growth = @cGrowth
--   WHERE char_id = @nCharId
--
-- Translation notes:
--   * inventory_growth is the *base* (non-cash) inventory expansion tier.
--     NCSoft AION ships 27-slot base bag; each tier widens visible slot
--     window by a class-specific delta (gladiator/templar +9 per tier,
--     etc.). Server keeps the raw counter; client renders the slot mask.
--     Pinned: server is dumb about the rendering rule.
--   * Sibling SPs (00240/00241/00242) target cashitem_inventory_growth /
--     char_warehouse_growth / cashitem_warehouse_growth on the same
--     user_data row — kept as 4 separate SPs because NCSoft's audit /
--     logd pipeline keys on the SP name, NOT the column name. Pinned:
--     do not collapse to a parameterised "SetGrowth(col, val)".
--   * Silent no-op on missing char_id. Pinned. NCSoft does not surface
--     "char gone" via this SP — the mall transaction had already taken
--     the kinah / cash-shop credit upstream.
--   * @cGrowth is TINYINT (0-255) → SMALLINT in PG (user_data column is
--     SMALLINT NOT NULL DEFAULT 0 from 00032 round-3 scaffold).
--   * VOLATILE. RETURNS VOID.
--
-- Bug-for-bug:
--   * NO upper-bound CHECK on growth tier. NCSoft enforces ceiling
--     client-side via item-shop catalogue (max tier 6 in 5.8 era);
--     server accepts any byte.
--   * NO ownership / banned guard. delete_date is NOT consulted —
--     contrast with 00208 ChangeEnhancedStigmaSlotCnt which does check.
--     Pinned: NCSoft accepted the inconsistency.
--   * Concurrent calls race on the column write — last-writer-wins.
--     Pinned. The mall workflow serialises upstream so racing within a
--     single char is a non-issue in practice.
--
-- Used by:
--   scripts/handlers/cm_inventory_expand.lua   -- consume inventory-expand item
--   scripts/lib/shop.lua                       -- cash-shop redemption hook

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinventorygrowth(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : owning user_data.char_id
-- _growth  : new tier (TINYINT 0-255 in T-SQL → SMALLINT in PG)
CREATE OR REPLACE FUNCTION aion_setinventorygrowth(
    _char_id INTEGER,
    _growth  SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET inventory_growth = _growth
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinventorygrowth(INTEGER, SMALLINT);
-- +goose StatementEnd
