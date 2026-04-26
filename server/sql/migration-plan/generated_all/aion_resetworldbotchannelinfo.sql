-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ResetWorldBotChannelInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_resetworldbotchannelinfo()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM world_bot_channel_info;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_resetworldbotchannelinfo;
-- +goose StatementEnd
