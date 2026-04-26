-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddWorldBotChannelInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addworldbotchannelinfo(_char_id INTEGER, _account_id INTEGER, _world_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS(SELECT char_id FROM world_bot_channel_info(updlock) WHERE char_id = _char_id)

begin

	UPDATE world_bot_channel_info SET world_id = _world_id WHERE char_id = _char_id	

end

	INSERT world_bot_channel_info (char_id, account_id, world_id) VALUES (_char_id, _account_id, _world_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addworldbotchannelinfo;
-- +goose StatementEnd
