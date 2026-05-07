-- AionCore 5.8 — Sprint 1.1a batch 7 port: aion_GetGatherCoolTimeList (login gather-cooltime hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetGatherCoolTimeList.sql
-- Original (T-SQL):
--   select cooltime_id, expire_cooltime
--   from user_gather_cooltime
--   where char_id = @char_id
--
-- Translation notes:
--   * Sister of user_combine_cooltime (00167) — same per-row schema, but
--     for gathering nodes (essence/aether/herb/wood). NCSoft uses gather
--     cooltime to throttle node respawns relative to the player (so a
--     player can't farm one rich node forever; once gathered it's on
--     cooldown for that char).
--   * Per-row state:
--       - cooltime_id     INTEGER : gather-class catalog id (5.8 gather_cool_time.xml)
--       - expire_cooltime BIGINT  : unix epoch ms when this cooldown ends.
--                                   NCSoft semantics is "expire_cooltime <= now()
--                                   means available", BUT the SP returns ALL rows
--                                   and the client/Lua filters. We preserve this:
--                                   no WHERE expire_cooltime > now() in PG.
--   * BIGINT in PG matches NCSoft `bigint` — milliseconds, not seconds.
--   * PRIMARY KEY (char_id, cooltime_id) — a gather class throttle is unique per char.
--   * Function declared STABLE.
--   * Table is created here (first SP in the gather-cooltime chain) using
--     IF NOT EXISTS so co-batch 00173 (Put) is safely re-runnable.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- gather cooltime hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_gather_cooltime (
    char_id         INTEGER NOT NULL,
    cooltime_id     INTEGER NOT NULL,
    expire_cooltime BIGINT  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, cooltime_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_gather_cooltime_char ON user_gather_cooltime(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getgathercooltimelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getgathercooltimelist(_char_id INTEGER)
RETURNS TABLE (
    cooltime_id     INTEGER,
    expire_cooltime BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ugc.cooltime_id, ugc.expire_cooltime
          FROM user_gather_cooltime ugc
         WHERE ugc.char_id = _char_id
         ORDER BY ugc.cooltime_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getgathercooltimelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_gather_cooltime_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_gather_cooltime;
-- +goose StatementEnd
