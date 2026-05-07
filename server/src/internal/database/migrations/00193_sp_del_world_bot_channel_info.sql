-- AionCore 5.8 — Sprint 1.1a batch 11 port: aion_DelWorldBotChannelInfo.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DelWorldBotChannelInfo.sql
-- Original (T-SQL):
--   DELETE FROM world_bot_channel_info WHERE char_id = @nCharId
--
-- Translation notes:
--   * Pure DELETE keyed by char_id. Removes ALL rows for that char (matters
--     because 00192 AddWorldBotChannelInfo can leave fan-out duplicates —
--     see 00192 notes). Called on logout / channel-leave to clean the
--     binding so the next login can re-register.
--   * Returns rows-affected as a sanity check. 0 = no binding existed,
--     1+ = removed N rows (N may be >1 thanks to 00192 dup behaviour).
--     Caller logs a warning when N > 1 to surface the fan-out.
--   * Table world_bot_channel_info created in 00192. Migration is
--     order-dependent on 00192 having run first.
--
-- Used by:
--   scripts/handlers/cm_quit.lua            -- on player logout
--   scripts/handlers/cm_change_channel.lua  -- before re-add at new channel
--   scripts/lib/world_bot.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_delworldbotchannelinfo(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_delworldbotchannelinfo(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM world_bot_channel_info WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_delworldbotchannelinfo(INTEGER);
-- +goose StatementEnd
