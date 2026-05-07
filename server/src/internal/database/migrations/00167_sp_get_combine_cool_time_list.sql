-- AionCore 5.8 — Sprint 1.1a batch 6 port: aion_GetCombineCoolTimeList (login combine-cooltime hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCombineCoolTimeList.sql
-- Original (T-SQL):
--   select cooltime_id, expire_cooltime
--   from user_combine_cooltime
--   where char_id = @char_id
--
-- Translation notes:
--   * Sister of user_item_cooltime (00166), but per-row not blob: combine
--     cooldown is the recipe-class throttle (e.g. "godstone fusion"
--     30-day cooldown). Each row is one (cooltime_id, expire_cooltime) pair.
--   * Per-row state:
--       - cooltime_id     INTEGER : combine-class catalog id (5.8 combine_cool_time.xml)
--       - expire_cooltime BIGINT  : unix epoch ms when this cooldown ends.
--                                   NCSoft semantics is "expire_cooltime <= now()
--                                   means available", BUT the SP returns ALL rows
--                                   and the client/Lua filters. We preserve this:
--                                   no WHERE expire_cooltime > now() in PG.
--   * BIGINT in PG matches NCSoft `bigint` — milliseconds, not seconds.
--   * PRIMARY KEY (char_id, cooltime_id) — a combine class throttle is unique per char.
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- combine cooltime hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_combine_cooltime (
    char_id         INTEGER NOT NULL,
    cooltime_id     INTEGER NOT NULL,
    expire_cooltime BIGINT  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, cooltime_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_combine_cooltime_char ON user_combine_cooltime(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcombinecooltimelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcombinecooltimelist(_char_id INTEGER)
RETURNS TABLE (
    cooltime_id     INTEGER,
    expire_cooltime BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uct.cooltime_id, uct.expire_cooltime
          FROM user_combine_cooltime uct
         WHERE uct.char_id = _char_id
         ORDER BY uct.cooltime_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcombinecooltimelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_combine_cooltime_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_combine_cooltime;
-- +goose StatementEnd
