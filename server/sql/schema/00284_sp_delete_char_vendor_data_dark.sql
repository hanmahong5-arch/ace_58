-- AionCore 5.8 — batch 28 / 4 of 5 ("Delete-族杂项"):
--   aion_DeleteCharVendorDataDark — Asmodian-side per-char vendor cleanup
--   on character delete (사용자 삭제시 관련 데이터 정리).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteCharVendorDataDark.sql
-- Original (T-SQL):
--   CREATE PROCEDURE [dbo].[aion_DeleteCharVendorDataDark]
--       @charId INT
--   AS
--   SET NOCOUNT ON
--   DELETE FROM vendor_item_dark
--   WHERE   (char_id = @charId)
--   DELETE FROM vendor_log_dark
--   WHERE   (char_id = @charId)
--   SET NOCOUNT OFF
--
-- Domain (vendor_item / vendor_log — Dark = Asmodian faction):
--   * vendor_item_dark : currently-listed Asmodian player-vendor items
--     (PK = user_item_id; cols come from aion_PutVendorItemDark — see
--     ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutVendorItemDark.sql).
--   * vendor_log_dark  : Asmodian player-vendor sales history (cols from
--     aion_PutVendorLogDark — wider schema; we model the keys + the
--     "important to bug-for-bug" subset, mirroring NCSoft minimal needs
--     for the DELETE-by-char_id contract).
--   These two tables are created HERE (this SP and 00285 are the first
--   migrations in the catalogue that reference them; future Put/Get vendor
--   SPs will reuse the schemas via CREATE TABLE IF NOT EXISTS or refine
--   columns).
--
-- Translation notes:
--   * Two-statement DELETE (item, then log). NCSoft runs both
--     unconditionally — there is NO transaction wrapper, NO error
--     short-circuit; both DELETEs always execute. We keep the same shape:
--     two DELETE statements inside one plpgsql body. The body itself is
--     atomic relative to the *caller* (a single SQL statement = one
--     implicit transaction in PG when called outside an explicit BEGIN).
--   * NCSoft uses unquoted `vendor_item_dark` / `vendor_log_dark`. SQL
--     Server is case-insensitive on identifiers; PG folds unquoted to
--     lowercase. Both server engines therefore resolve to the all-lower
--     table name. Pinned: lowercase, no double-quotes.
--   * Returns INTEGER rows-affected — SUM of both deletes (item + log).
--     This is a strict widening of NCSoft's VOID return (callers may
--     ignore). Sum (not pair) chosen to match the convention of 00251
--     DeletePvPEnv / 00260 DeleteAuctionBetting — single INTEGER suffices
--     and the breakdown is rarely needed at the call site.
--
-- Bug-for-bug:
--   * No transaction / savepoint — partial failure (e.g. log table
--     locked) leaves item table cleaned, log dirty. NCSoft same. Pinned.
--   * No FK validation on char_id — char that never sold anything yields
--     0 + 0 = 0; pinned.
--   * Cross-faction isolation: this SP touches ONLY the *_dark tables.
--     vendor_item_light / vendor_log_light are NOT touched even if a
--     mis-recorded row exists there with the same char_id (which is
--     impossible by design — char faction is fixed). Pinned: 00285 owns
--     the Light-faction equivalent.
--
-- Used by:
--   scripts/lib/char_delete.lua  -- char-delete cascade (Dark branch)

-- +goose Up
-- +goose StatementBegin
-- vendor_item_dark — currently-listed Asmodian vendor items.
-- Schema mirrors aion_PutVendorItemDark column list: char_id + user_item_id
-- + price + amount + commit_date. user_item_id is the natural PK (NCSoft
-- guards "if not exists" on user_item_id alone in PutVendorItemDark).
CREATE TABLE IF NOT EXISTS vendor_item_dark (
    char_id        INTEGER NOT NULL,
    user_item_id   BIGINT  NOT NULL,
    user_price     BIGINT  NOT NULL DEFAULT 0,
    sale_price     BIGINT  NOT NULL DEFAULT 0,
    commit_amount  BIGINT  NOT NULL DEFAULT 0,
    remain_amount  BIGINT  NOT NULL DEFAULT 0,
    commit_date    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_item_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_vendor_item_dark_char ON vendor_item_dark(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- vendor_log_dark — Asmodian vendor sales log.
-- Schema mirrors aion_PutVendorLogDark column list (subset — full set is
-- 25+ cols including stat_enchant_name0..5, dye_info, producer, etc.; we
-- model the keys + amount/price + soul_bound + enchant_count, leaving
-- the rest as nullable for future Put SP migrations to refine).
CREATE TABLE IF NOT EXISTS vendor_log_dark (
    log_id           BIGSERIAL,
    char_id          INTEGER NOT NULL,
    item_name_id     INTEGER NOT NULL,
    sold_price       BIGINT  NOT NULL DEFAULT 0,
    sold_amount      BIGINT  NOT NULL DEFAULT 0,
    remain_amount    BIGINT  NOT NULL DEFAULT 0,
    sold_date        INTEGER NOT NULL DEFAULT 0,
    soul_bound       SMALLINT NOT NULL DEFAULT 0,    -- TINYINT → SMALLINT
    enchant_count    SMALLINT NOT NULL DEFAULT 0,    -- TINYINT → SMALLINT
    skin_name_id     INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (log_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_vendor_log_dark_char ON vendor_log_dark(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletecharvendordatadark(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : char whose Dark-faction vendor data is wiped.
-- Returns sum of rows deleted across both vendor_item_dark and
-- vendor_log_dark (strict widening of NCSoft VOID).
CREATE OR REPLACE FUNCTION aion_deletecharvendordatadark(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    item_cnt INTEGER;
    log_cnt  INTEGER;
BEGIN
    -- 1) Wipe currently-listed items.
    DELETE FROM vendor_item_dark WHERE char_id = _char_id;
    GET DIAGNOSTICS item_cnt = ROW_COUNT;

    -- 2) Wipe sales history. NCSoft runs both DELETEs unconditionally —
    -- mirror that ordering and lack of short-circuit.
    DELETE FROM vendor_log_dark  WHERE char_id = _char_id;
    GET DIAGNOSTICS log_cnt = ROW_COUNT;

    RETURN item_cnt + log_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletecharvendordatadark(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_vendor_log_dark_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_vendor_item_dark_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS vendor_log_dark;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS vendor_item_dark;
-- +goose StatementEnd
