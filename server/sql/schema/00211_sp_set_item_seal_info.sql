-- AionCore 5.8 — Sprint 1.1a batch 15 port: aion_SetItemSealInfo (item-seal UPSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetItemSealInfo.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT id FROM user_item_sealed(updlock) WHERE id = @item_id)
--       UPDATE user_item_sealed
--          SET sealExpiredTime=@expired_time, sealState=@seal_state, char_id=@char_id
--        WHERE id = @item_id
--   ELSE
--       INSERT INTO user_item_sealed (id, sealExpiredTime, sealState, char_id)
--       VALUES (@item_id, @expired_time, @seal_state, @char_id)
--
-- Schema delta:
--   First port to touch user_item_sealed — table does not yet exist in PG.
--   Create with NCSoft's PascalCase column names preserved verbatim
--   (sealExpiredTime, sealState) and quoted in DDL/SQL so PG keeps the
--   case. Per cross-cutting CLAUDE.md guidance: "PostgreSQL identifiers must
--   be double-quoted to preserve case" — and these come straight from
--   user-visible NCSoft schema. id is the user_item.id surrogate key (BIGINT
--   in NCSoft; we pin BIGINT so future joins to user_item — also BIGSERIAL —
--   are type-compatible).
--
-- Translation notes:
--   * NCSoft column types:
--       id              BIGINT  (PK, also FK-shaped — points to user_item.id)
--       sealExpiredTime INT     (epoch seconds; NCSoft will overflow at 2038)
--       sealState       INT     (0=unsealed, 1=sealed, 2=cooldown — see client)
--       char_id         INT
--     PG side keeps int/bigint widths exactly; sealExpiredTime stays INTEGER
--     for byte-perfect parity (matches T-SQL @expired_time INT).
--   * IF EXISTS … UPDATE … ELSE INSERT collapses to ON CONFLICT (id) DO UPDATE.
--     The T-SQL UPDLOCK hint translates to PG's row-lock-on-conflict semantics
--     of UPSERT (no explicit lock needed; ON CONFLICT serializes per row).
--   * Returns rows-affected (1 for either branch — UPSERT always touches).
--
-- Bug-for-bug:
--   * char_id is OVERWRITTEN on update — so re-sealing transfers ownership
--     of the seal record to the caller's char_id. NCSoft uses this as a
--     "last-toucher wins" model when an item changes hands while sealed.
--     Pinned verbatim — do NOT silently keep the original char_id.
--   * No FK on user_item_sealed.id → user_item(id). NCSoft has none either;
--     a sealed-info row can outlive its parent item (forensic / audit
--     property the GM tools rely on).
--
-- Used by:
--   scripts/handlers/cm_item_seal.lua          (player-initiated seal)
--   scripts/handlers/cm_item_seal_unseal.lua   (player-initiated unseal)
--   scripts/lib/item_seal.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_item_sealed — first introduction of this table. Column names
-- preserved with NCSoft PascalCase (sealExpiredTime / sealState). PG will
-- fold them to lowercase unless quoted; we quote in DDL and SQL alike.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_item_sealed (
    id                BIGINT  PRIMARY KEY,
    "sealExpiredTime" INTEGER NOT NULL DEFAULT 0,
    "sealState"       INTEGER NOT NULL DEFAULT 0,
    char_id           INTEGER NOT NULL
);
-- +goose StatementEnd

-- +goose StatementBegin
-- NCSoft has IX_user_item_sealed_char_id (referenced by aion_GetItemSealInfo
-- with index hint). Mirror it so per-char list scans stay cheap.
CREATE INDEX IF NOT EXISTS idx_user_item_sealed_char_id
    ON user_item_sealed(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemsealinfo(INTEGER, BIGINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemsealinfo(
    _char_id        INTEGER,
    _item_id        BIGINT,
    _seal_state     INTEGER,
    _expired_time   INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- UPSERT on PK(id). char_id is intentionally overwritten on UPDATE —
    -- NCSoft's "last-toucher wins" for seal ownership transfer.
    INSERT INTO user_item_sealed (id, "sealExpiredTime", "sealState", char_id)
    VALUES (_item_id, _expired_time, _seal_state, _char_id)
    ON CONFLICT (id) DO UPDATE SET
        "sealExpiredTime" = EXCLUDED."sealExpiredTime",
        "sealState"       = EXCLUDED."sealState",
        char_id           = EXCLUDED.char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemsealinfo(INTEGER, BIGINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_item_sealed_char_id;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_item_sealed;
-- +goose StatementEnd
