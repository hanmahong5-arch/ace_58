-- AionCore 5.8 — Sprint 1.1a batch 4 port: aion_ClientSettingsPut (upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClientSettingsPut.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT char_id FROM user_client_settings(UPDLOCK)
--               WHERE char_id = @char_id)
--     UPDATE user_client_settings
--        SET data_size = @data_size, data = @data
--      WHERE char_id = @char_id
--   ELSE
--     INSERT user_client_settings(char_id, data_size, data)
--          VALUES (@char_id, @data_size, @data)
--
-- Translation notes:
--   * The IF EXISTS / UPDATE-or-INSERT pattern is the canonical SQL Server
--     2000 upsert; PG side collapses it into `INSERT ... ON CONFLICT DO UPDATE`
--     which is genuinely atomic (no UPDLOCK race window between the SELECT
--     and the INSERT branch). Two concurrent puts on the same char_id are
--     serialised at the index level, last-writer-wins — same semantics as
--     the original after the lock hint absorbs them.
--   * The blob (`@data` varbinary(7168) → BYTEA) and `data_size` smallint are
--     passed straight through; the server treats the payload as opaque (see
--     00154 for the matching reader).
--   * Returns rows-affected (always 1 for a successful upsert) so the caller
--     can sanity-check the round-trip — matches the convention used by
--     aion_AddBuddy (00144) and aion_SetItemWarehouse (00134).
--   * Table is created idempotently (00154 also has IF NOT EXISTS) so this
--     migration is order-independent w.r.t. 00154 — important for partial
--     re-runs against a fresh DB.
--
-- Used by:
--   scripts/handlers/cm_client_settings_save.lua  -- on logout / explicit save
--   scripts/lib/client_settings.lua

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_client_settings (
    char_id    INTEGER  PRIMARY KEY,
    data_size  SMALLINT NOT NULL DEFAULT 0,
    data       BYTEA    NOT NULL DEFAULT '\x'::BYTEA
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clientsettingsput(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clientsettingsput(
    _char_id   INTEGER,
    _data_size SMALLINT,
    _data      BYTEA
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    INSERT INTO user_client_settings(char_id, data_size, data)
    VALUES (_char_id, _data_size, _data)
    ON CONFLICT (char_id) DO UPDATE
       SET data_size = EXCLUDED.data_size,
           data      = EXCLUDED.data;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clientsettingsput(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd
