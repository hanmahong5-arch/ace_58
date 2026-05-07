-- AionCore 5.8 — Sprint 1.1a batch 16 port: aion_GetWardrobe (wardrobe SELECT-by-char).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetWardrobe.sql
-- Original (T-SQL):
--   SELECT slot_id, name_id
--   FROM user_wardrobe WITH(NOLOCK)
--   WHERE char_id = @nCharId
--
-- Schema delta:
--   First port to touch user_wardrobe — table does not yet exist in PG.
--   Wardrobe (Luna Wardrobe / 衣橱) lets a char register costume entries
--   keyed by slot_id. Each (char_id, slot_id) is unique — NCSoft enforces
--   via clustered PK on (char_id, slot_id). Mirrored as a composite PK in PG.
--
-- Translation notes:
--   * NCSoft column types (verified against schema dump):
--       char_id  INT   (FK-shaped to user_data.char_id; not enforced — see
--                       bug-for-bug)
--       slot_id  INT   (wardrobe slot index 0..N; client-side enum)
--       name_id  INT   (item name id reference; client-side resource id)
--   * Composite PK (char_id, slot_id) — mirrors NCSoft's clustered index.
--     This serves as both unique-key and the per-char scan index used
--     by this Get SP.
--   * `WITH(NOLOCK)` is dirty-read in T-SQL; PG MVCC snapshot already
--     provides the non-blocking read property. Dropped (matches the
--     00148 GetFamiliarList / 00212 GetItemSealInfo precedent).
--   * STABLE marker — pure SELECT, planner-inlinable.
--   * Empty result for chars with no wardrobe entries → zero rows.
--
-- Bug-for-bug:
--   * No FK on user_wardrobe.char_id → user_data.char_id. NCSoft has none.
--     Wardrobe entries can outlive their char (forensic / audit property).
--     Pinned verbatim — do NOT add a FK constraint.
--   * No filter on validity / expiration — wardrobe entries are timeless;
--     the client decides display.
--
-- Used by:
--   scripts/handlers/cm_wardrobe_list.lua  (post-login wardrobe snapshot)
--   scripts/lib/wardrobe.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_wardrobe — first introduction. Composite PK (char_id, slot_id)
-- reproduces NCSoft's clustered index and enforces single-entry-per-slot
-- semantics expected by the client.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_wardrobe (
    char_id  INTEGER NOT NULL,
    slot_id  INTEGER NOT NULL,
    name_id  INTEGER NOT NULL,
    PRIMARY KEY (char_id, slot_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwardrobe(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getwardrobe(_char_id INTEGER)
RETURNS TABLE (
    slot_id INTEGER,
    name_id INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT w.slot_id, w.name_id
          FROM user_wardrobe w
         WHERE w.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwardrobe(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_wardrobe;
-- +goose StatementEnd
