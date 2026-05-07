-- AionCore 5.8 — Sprint 1.1a batch 20 port: aion_SetFamiliarName
-- (rename a familiar — hot-reset name + bump update_time).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetFamiliarName.sql
-- Original (T-SQL):
--   UPDATE user_familiar
--   SET name = @name, update_time = @updateTime
--   WHERE id = @dbId AND char_id = @masterId
--
-- Translation notes:
--   * Single-column rename + update_time. Companion to PutFamiliar (which
--     sets the initial name) and SetFamiliarInfo (which never touches the
--     name column). Triggered by the in-game "rename familiar" item.
--   * Same defensive `id AND char_id` ownership WHERE as siblings.
--     Pinned.
--   * @name is NVARCHAR(50) — TEXT in PG. The user_familiar.name column
--     is TEXT NOT NULL DEFAULT '' (00115 scaffold). No length CHECK in PG;
--     caller pre-validates. NCSoft client-side enforces 12-char display
--     cap but server only sees the raw bytes. Pinned: server is dumb
--     about display rules.
--   * Silent no-op on missing row. Pinned.
--   * VOLATILE. RETURNS VOID.
--
-- Bug-for-bug:
--   * NO uniqueness check on familiar names — two familiars under the
--     same master can collide. NCSoft live behaviour. Pinned.
--   * No profanity / banned-name filter at the SP layer; that lives in
--     the Lua handler before the SP is called. Pinned.
--   * No audit trail (the previous name is overwritten without history).
--     Pinned. GM rename-history must be reconstructed from logd ClickHouse
--     pipeline if needed.
--
-- Used by:
--   scripts/handlers/cm_familiar_rename.lua   -- consume rename-coupon item
--   scripts/lib/familiar.lua                  -- shared rename helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarname(BIGINT, INTEGER, TEXT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _db_id        : user_familiar.id (BIGSERIAL PK)
-- _master_id    : owning char_id (defensive ownership filter)
-- _name         : new display name (NVARCHAR(50) → TEXT, caller validates)
-- _update_time  : caller epoch-millis
CREATE OR REPLACE FUNCTION aion_setfamiliarname(
    _db_id       BIGINT,
    _master_id   INTEGER,
    _name        TEXT,
    _update_time BIGINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_familiar
       SET name        = _name,
           update_time = _update_time
     WHERE id      = _db_id
       AND char_id = _master_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarname(BIGINT, INTEGER, TEXT, BIGINT);
-- +goose StatementEnd
