-- AionCore 5.8 — Sprint 1.1a batch 8 port: aion_SetPetitionWebNotify (web-petition opt-in upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetPetitionWebNotify.sql
-- Original (T-SQL):
--   IF NOT EXISTS (SELECT id FROM user_petition_web(updlock) WHERE char_id = @nCharId)
--     INSERT INTO user_petition_web(char_id) VALUES (@nCharId)
--
-- Translation notes:
--   * Idempotent insert: "make sure char is opted in, no-op if already".
--     PG `INSERT ... ON CONFLICT DO NOTHING` is the natural translation —
--     it is genuinely atomic at the index level (UNIQUE on char_id), unlike
--     the SQL Server IF-EXISTS-then-INSERT which has a UPDLOCK race window.
--   * Returns rows-affected so the caller can distinguish "newly opted in"
--     (1) from "was already opted in" (0). Matches the convention from
--     00170 / 00155 / 00144.
--   * Table DDL co-located with 00174 (Get) / 00176 (Clear) via IF NOT
--     EXISTS so this migration is order-independent.
--
-- Used by:
--   scripts/handlers/cm_petition_web_notify_set.lua   -- player toggles opt-in ON

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_petition_web (
    id      BIGSERIAL PRIMARY KEY,
    char_id INTEGER NOT NULL UNIQUE
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetitionwebnotify(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetitionwebnotify(_char_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    INSERT INTO user_petition_web(char_id)
    VALUES (_char_id)
    ON CONFLICT (char_id) DO NOTHING;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetitionwebnotify(INTEGER);
-- +goose StatementEnd
