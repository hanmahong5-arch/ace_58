-- AionCore 5.8 — Sprint 1.1a batch 8 port: aion_GetPetitionWebNotify (web-petition opt-in lookup).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetPetitionWebNotify.sql
-- Original (T-SQL):
--   SELECT char_id FROM user_petition_web WHERE char_id = @nCharId
--
-- Translation notes:
--   * `user_petition_web` is the per-character "I want web-channel petition
--     responses" opt-in registry. The original NCSoft schema stores ONLY
--     (id BIGSERIAL surrogate, char_id INT) — there is no per-row payload;
--     mere existence of the row is the signal. We mirror that exactly:
--     return char_id (echo of the input) when the row exists, 0 rows
--     otherwise. The 5.8 client reads the result count, not the value.
--   * Created here as the first SP in the petition-web triplet (Get/Set/Clear)
--     to reach a fresh DB. 00175 / 00176 re-declare IF NOT EXISTS so the
--     migrations stay independent of run order — same scaffold-on-first-use
--     pattern as user_macro (00169) / user_comment (00156).
--   * `id` PK is BIGSERIAL even though no SP returns it — NCSoft schema has
--     it as a surrogate identity column on the SQL Server side, so we keep
--     it for round-trip parity if a future SP exposes it.
--   * Function declared STABLE — pure read.
--
-- Used by:
--   scripts/handlers/cm_petition_web_notify_get.lua   -- on enter-world poll

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_petition_web (
    id      BIGSERIAL PRIMARY KEY,
    char_id INTEGER NOT NULL UNIQUE
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_petition_web_char ON user_petition_web(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetitionwebnotify(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpetitionwebnotify(_char_id INTEGER)
RETURNS TABLE (
    char_id INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT upw.char_id
          FROM user_petition_web upw
         WHERE upw.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetitionwebnotify(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_petition_web_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_petition_web;
-- +goose StatementEnd
