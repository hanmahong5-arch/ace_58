-- AionCore 5.8 — Sprint 1.1a batch 13 port: aion_PutBookmark (world-map favorite writer).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutBookmark.sql
-- Original (T-SQL):
--   INSERT bookmark (char_id, bookmark, world, x, y, z)
--   VALUES (@nCharId, @strBookmark, @nWorld, @nX, @nY, @nZ)
--
-- Translation notes:
--   * Plain INSERT — NO upsert, NO existence guard. Source `aion_PutBookmark`
--     trusts the client to choose a fresh `bookmark` slot id. If the client
--     reuses a slot, T-SQL raises a PK violation and the SP fails with an
--     error returned to the caller. PRESERVED VERBATIM (bug-for-bug):
--     this is the bug surface NCSoft documents in their internal ticket
--     "Bookmark/2" — caller must DELETE then INSERT for slot reuse.
--   * NCSoft `bookmark` column is `nvarchar(30)` — the human-readable label
--     the player typed in for the favorite. Round 6 scaffold (00164) used
--     `bookmark SMALLINT` as a slot index — that's a SCHEMA DIVERGENCE.
--     The original NCSoft schema has TWO columns: `bookmark` (nvarchar label)
--     AND a separate slot-id (likely an autonumber). Looking at 00164's
--     TABLE definition more carefully, only the slot-style `bookmark SMALLINT`
--     was scaffolded — the NCSoft label column was missed. We add it here as
--     `bookmark_name TEXT NOT NULL DEFAULT ''` (additive, no row touched).
--     Future GetBookmark wire-format port will pick it up.
--   * world INTEGER, x/y/z REAL — already match.
--   * The NCSoft procedure has 6 args (char_id, label, world, x, y, z). The
--     PG signature mirrors that. The PK is (char_id, bookmark_slot) — we name
--     the parameter `_slot` to make the slot-vs-label distinction explicit.
--   * Returns rows-affected (1 = inserted; PK violation surfaces as an error,
--     not a 0 return — bug-for-bug NCSoft).
--
-- Used by:
--   scripts/handlers/cm_bookmark_add.lua  -- on /bookmark add
--   scripts/lib/bookmark.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- bookmark — additive widening with the NCSoft label column. Existing rows
-- (none on a fresh DB) get '' default; future writers populate it.
-- ====================================================================
ALTER TABLE bookmark
    ADD COLUMN IF NOT EXISTS bookmark_name TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbookmark(INTEGER, SMALLINT, TEXT, INTEGER, REAL, REAL, REAL);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putbookmark(
    _char_id        INTEGER,
    _slot           SMALLINT,
    _bookmark_name  TEXT,
    _world          INTEGER,
    _x              REAL,
    _y              REAL,
    _z              REAL
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Plain INSERT, no ON CONFLICT. Slot-reuse raises 23505 unique_violation,
    -- bubbled up to the caller — NCSoft bug-for-bug. Caller is expected to
    -- DELETE the slot first if reusing.
    INSERT INTO bookmark (char_id, bookmark, bookmark_name, world, x, y, z)
    VALUES (_char_id, _slot, _bookmark_name, _world, _x, _y, _z);
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbookmark(INTEGER, SMALLINT, TEXT, INTEGER, REAL, REAL, REAL);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE bookmark
    DROP COLUMN IF EXISTS bookmark_name;
-- +goose StatementEnd
