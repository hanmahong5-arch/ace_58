-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_GetDeletedCharList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetDeletedCharList.sql
--
-- Lists characters whose 7-day soft-delete grace has elapsed and that have
-- not yet been finally purged (delete_complete_date = 0). Consumed by the
-- nightly sweeper job that calls the cascade-Delete chain
-- (DeleteItemByChar / DeleteAllSkill / DeleteAllQuest / DeleteChar / …).
--
-- T-SQL body:
--   SELECT char_id, user_id, account_id, account_name, guild_id, guild_rank
--   FROM user_data with(nolock, index=IX_delete_complete_date)
--   WHERE delete_complete_date = 0
--     AND delete_date > 0
--     AND delete_date <= @nCurTime
--
-- @nServerId is unused in the body — NCSoft kept it for future per-shard
-- partitioning that never shipped. We accept it for wire compatibility but
-- do not filter on it.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdeletedcharlist(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdeletedcharlist(
    _server_id INTEGER,
    _cur_time  INTEGER
)
RETURNS TABLE (
    char_id      INTEGER,
    user_id      TEXT,
    account_id   INTEGER,
    account_name TEXT,
    guild_id     INTEGER,
    guild_rank   INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    -- _server_id intentionally unused (verbatim with NCSoft).
    PERFORM _server_id;
    RETURN QUERY
        SELECT ud.char_id, ud.user_id, ud.account_id, ud.account_name,
               ud.guild_id, ud.guild_rank
          FROM user_data ud
         WHERE ud.delete_complete_date = 0
           AND ud.delete_date > 0
           AND ud.delete_date <= _cur_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdeletedcharlist(INTEGER, INTEGER);
-- +goose StatementEnd
