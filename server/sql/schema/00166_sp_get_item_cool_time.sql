-- AionCore 5.8 — Sprint 1.1a batch 6 port: aion_GetItemCoolTime (login item-cooltime blob hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetItemCoolTime.sql
-- Original (T-SQL):
--   select cooltime_data_cnt, data from user_item_cooltime where char_id = @char_id
--
-- Translation notes:
--   * NCSoft packs all per-item cooldown timers into a single opaque BLOB so
--     the wire/save format can change without schema migrations. We keep the
--     same blob contract: `data` is opaque BYTEA, never parsed in PG.
--   * Per-row state:
--       - cooltime_data_cnt SMALLINT : count of (item_id,expire_ms) tuples in the blob
--       - data              BYTEA    : packed tuple stream (NCSoft proprietary layout)
--   * One row per char (PRIMARY KEY char_id) — same single-row blob pattern as
--     user_client_settings (00154), quickbar (00160), favorite (00161).
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- item cooltime hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_item_cooltime (
    char_id            INTEGER  PRIMARY KEY,
    cooltime_data_cnt  SMALLINT NOT NULL DEFAULT 0,
    data               BYTEA    NOT NULL DEFAULT '\x'::BYTEA
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemcooltime(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemcooltime(_char_id INTEGER)
RETURNS TABLE (
    cooltime_data_cnt SMALLINT,
    data              BYTEA
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uic.cooltime_data_cnt, uic.data
          FROM user_item_cooltime uic
         WHERE uic.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemcooltime(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_item_cooltime;
-- +goose StatementEnd
