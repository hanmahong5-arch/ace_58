-- AionCore 5.8 — Sprint 1.1a batch 8 port: aion_ClearPetitionWebNotify (web-petition opt-out).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClearPetitionWebNotify.sql
-- Original (T-SQL):
--   delete from user_petition_web where char_id = @nCharId
--
-- Translation notes:
--   * Single-row DELETE keyed on char_id (UNIQUE → at most 1 row affected).
--     Returns rows-affected so the caller can distinguish "opt-out applied"
--     (1) from "was already opted out" (0) — useful for the toggle handler
--     which sometimes issues a Clear for a state the client thinks is on
--     but the server already cleared (race after a re-login).
--   * Table DDL co-located with 00174 / 00175 via IF NOT EXISTS, so this
--     migration is order-independent.
--   * NOT declared STABLE — it mutates state.
--
-- Used by:
--   scripts/handlers/cm_petition_web_notify_clear.lua   -- player toggles opt-in OFF

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_petition_web (
    id      BIGSERIAL PRIMARY KEY,
    char_id INTEGER NOT NULL UNIQUE
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearpetitionwebnotify(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearpetitionwebnotify(_char_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM user_petition_web
     WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearpetitionwebnotify(INTEGER);
-- +goose StatementEnd
