-- AionCore 5.8 — Sprint 1.1a batch 5 port: aion_GetTitle (login title-list hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetTitle.sql
-- Original (T-SQL):
--   SELECT title_id, is_have, expired_time FROM user_title WHERE char_id=@nUserId
--
-- Translation notes:
--   * NCSoft `user_title` tracks every title the character has ever been
--     awarded. Per-row state:
--       - title_id      INT  : 5.8 client_titles.xml id
--       - is_have       BIT  : currently equipped flag (only one true per char)
--       - expired_time  BIGINT (unix epoch seconds) : 0 = permanent, else expiry
--   * `is_have` is a SQL Server BIT (0/1). PG side uses BOOLEAN — natural
--     fit, and Go scans into bool cleanly. Wire-side conversion happens
--     in the handler (writes 1 byte 0/1) so this is hidden from the client.
--   * `expired_time` is BIGINT unix epoch (NCSoft semantics — application
--     code computes wall-clock from current epoch); deliberately NOT
--     TIMESTAMPTZ for the same drift-avoidance reason as 00159.
--   * No source-side filter on expired titles — the client receives the
--     full list and decides whether to grey-out expired ones. Preserved.
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- title list hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_title (
    char_id      INTEGER NOT NULL,
    title_id     INTEGER NOT NULL,
    is_have      BOOLEAN NOT NULL DEFAULT FALSE,
    expired_time BIGINT  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, title_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_title_char ON user_title(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gettitle(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gettitle(_char_id INTEGER)
RETURNS TABLE (
    title_id     INTEGER,
    is_have      BOOLEAN,
    expired_time BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ut.title_id, ut.is_have, ut.expired_time
          FROM user_title ut
         WHERE ut.char_id = _char_id
         ORDER BY ut.title_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gettitle(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_title_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_title;
-- +goose StatementEnd
