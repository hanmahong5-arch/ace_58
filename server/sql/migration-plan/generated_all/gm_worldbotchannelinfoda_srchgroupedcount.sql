-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_WorldBotChannelInfoDA_SrchGroupedCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_worldbotchannelinfoda_srchgroupedcount()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



	SELECT	world_id as zone_id, COUNT(*) as user_cnt

	FROM	world_bot_channel_info (nolock)

	GROUP BY world_id

	ORDER BY world_id DESC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_worldbotchannelinfoda_srchgroupedcount;
-- +goose StatementEnd
