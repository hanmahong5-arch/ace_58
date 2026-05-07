-- AionCore 5.8 — Sprint 1.1a batch 25 port: aion_RemoveHouseField
-- (housing decoration row DELETE — house demolish / soft-reset).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_RemoveHouseField.sql
-- Original (T-SQL):
--   DELETE FROM house_field WHERE id = @id
--
-- Domain (`house_field`, batch 25 — final sister of 00261, 00262):
--   Removes a row from the decoration manifest. Called when:
--     * House is administratively deleted (GM tooling)
--     * Test scaffolding tears down a house instance
--   NCSoft does NOT call this on normal player ownership change —
--   the standard path is SetHouseField with a new owner_id (preserving
--   decoration history). Removal is rare.
--
-- Schema:
--   `house_field` is created by 00261. PK is `id` — single-row delete.
--
-- Translation notes:
--   * Single-statement DELETE. No UPDLOCK in NCSoft (single-row PK
--     delete is atomic on both engines).
--   * Returns INTEGER row-count (a strict widening of NCSoft VOID;
--     same convention as 00251 / 00253 / 00260). 0 = "id not found";
--     1 = "deleted".
--   * NO cascade behaviour for related tables (house_field_script,
--     house_object). NCSoft pinned: the SPs for those siblings are
--     called separately by the caller (Lua handler) — this SP
--     touches ONLY the manifest row.
--
-- Bug-for-bug:
--   * No FK validation; missing id → 0 affected, no error.
--   * Orphan house_field_script rows (referencing the deleted addr_id)
--     are NOT cleaned up by this SP. Pinned: NCSoft same gap. Caller
--     must manually clean dependent data, or rely on the
--     `aion_SetHouseFieldScript` upsert to overwrite.
--   * No archival / audit trail. The row is gone — recovery requires
--     PG point-in-time restore. Pinned.
--
-- Used by:
--   scripts/handlers/gm_house_field_delete.lua    -- GM demolish
--   scripts/lib/house.lua                          -- shared helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removehousefield(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _id : house_field.id (PK).
-- Returns INTEGER rows-affected (0 if id absent, 1 on delete).
CREATE OR REPLACE FUNCTION aion_removehousefield(
    _id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    DELETE FROM house_field WHERE id = _id;
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removehousefield(INTEGER);
-- +goose StatementEnd
