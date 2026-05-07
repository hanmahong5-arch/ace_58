-- AionCore 5.8 — batch 28 / 5 of 5 ("Delete-族杂项"):
--   aion_DeleteCharVendorDataLight — Elyos-side per-char vendor cleanup
--   on character delete (사용자 삭제시 관련 데이터 정리).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteCharVendorDataLight.sql
-- Original (T-SQL):
--   CREATE PROCEDURE [dbo].[aion_DeleteCharVendorDataLight]
--       @charId INT
--   AS
--   SET NOCOUNT ON
--   DELETE FROM vendor_item_light
--   WHERE   (char_id = @charId)
--   DELETE FROM vendor_log_light
--   WHERE   (char_id = @charId)
--   SET NOCOUNT OFF
--
-- Domain (vendor_item / vendor_log — Light = Elyos faction):
--   * Mirror image of 00284 — *_light tables instead of *_dark. The two
--     SPs are deliberately distinct in NCSoft (not parameterised on
--     faction) because faction is a write-time partition; cross-faction
--     contamination is impossible by design (char faction is fixed at
--     creation in user_data).
--   * Tables vendor_item_light / vendor_log_light are created here on the
--     same schema as the Dark sister (00284). Future Put/Get vendor SP
--     ports for the Light branch will reuse the same shape.
--
-- Translation notes:
--   * Two-statement DELETE (item, then log) — same shape as 00284.
--   * Returns INTEGER rows-affected — SUM of both deletes (item + log),
--     matching 00284's return convention.
--
-- Bug-for-bug:
--   * No transaction / savepoint — partial failure path matches NCSoft.
--   * No FK validation on char_id — char that never sold anything yields
--     0 + 0 = 0; pinned.
--   * Cross-faction isolation: this SP touches ONLY the *_light tables;
--     *_dark is invariant under this call. Pinned (NCSoft same).
--
-- Used by:
--   scripts/lib/char_delete.lua  -- char-delete cascade (Light branch)

-- +goose Up
-- +goose StatementBegin
-- vendor_item_light — currently-listed Elyos vendor items.
CREATE TABLE IF NOT EXISTS vendor_item_light (
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
CREATE INDEX IF NOT EXISTS idx_vendor_item_light_char ON vendor_item_light(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- vendor_log_light — Elyos vendor sales log.
CREATE TABLE IF NOT EXISTS vendor_log_light (
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
CREATE INDEX IF NOT EXISTS idx_vendor_log_light_char ON vendor_log_light(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletecharvendordatalight(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : char whose Light-faction vendor data is wiped.
-- Returns sum of rows deleted across both vendor_item_light and
-- vendor_log_light (strict widening of NCSoft VOID; 00284 sister).
CREATE OR REPLACE FUNCTION aion_deletecharvendordatalight(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    item_cnt INTEGER;
    log_cnt  INTEGER;
BEGIN
    -- 1) Wipe currently-listed items.
    DELETE FROM vendor_item_light WHERE char_id = _char_id;
    GET DIAGNOSTICS item_cnt = ROW_COUNT;

    -- 2) Wipe sales history. Same unconditional ordering as Dark sister.
    DELETE FROM vendor_log_light  WHERE char_id = _char_id;
    GET DIAGNOSTICS log_cnt = ROW_COUNT;

    RETURN item_cnt + log_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletecharvendordatalight(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_vendor_log_light_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_vendor_item_light_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS vendor_log_light;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS vendor_item_light;
-- +goose StatementEnd
