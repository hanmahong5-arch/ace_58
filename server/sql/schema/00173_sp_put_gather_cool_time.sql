-- AionCore 5.8 — Sprint 1.1a batch 7 port: aion_PutGatherCoolTime (upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutGatherCoolTime.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT char_id FROM user_gather_cooltime(UPDLOCK)
--               WHERE char_id = @char_id AND cooltime_id = @cooltime_id)
--     UPDATE user_gather_cooltime
--        SET expire_cooltime = @expire_cooltime
--      WHERE char_id = @char_id AND cooltime_id = @cooltime_id
--   ELSE
--     INSERT user_gather_cooltime(char_id, cooltime_id, expire_cooltime)
--          VALUES (@char_id, @cooltime_id, @expire_cooltime)
--
-- Translation notes:
--   * Same canonical SQL Server 2000 upsert pattern as 00170 (SetMacro)
--     and 00155 (ClientSettingsPut). PG `INSERT ... ON CONFLICT DO UPDATE`
--     is genuinely atomic — two concurrent gather-completion writes for
--     the same (char_id, cooltime_id) are serialised at the index level,
--     last-writer-wins.
--   * Composite key (char_id, cooltime_id) — a single char accumulates
--     multiple gather-class throttles, upsert keys on both. Table DDL
--     co-located with 00172 via IF NOT EXISTS.
--   * `expire_cooltime` BIGINT (unix epoch ms) passed straight through;
--     NCSoft writes the absolute deadline computed at gather-event time
--     (now_ms + class_cooldown_ms) — the SP doesn't compute it.
--   * Returns rows-affected (always 1 for a successful upsert).
--
-- Used by:
--   scripts/handlers/cm_gather_complete.lua   -- on successful gather node completion
--   scripts/lib/gather.lua

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
DROP FUNCTION IF EXISTS aion_putgathercooltime(INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putgathercooltime(
    _char_id         INTEGER,
    _cooltime_id     INTEGER,
    _expire_cooltime BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    INSERT INTO user_gather_cooltime(char_id, cooltime_id, expire_cooltime)
    VALUES (_char_id, _cooltime_id, _expire_cooltime)
    ON CONFLICT (char_id, cooltime_id) DO UPDATE
       SET expire_cooltime = EXCLUDED.expire_cooltime;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putgathercooltime(INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd
