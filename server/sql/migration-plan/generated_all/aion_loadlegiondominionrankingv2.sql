-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_LoadLegionDominionRankingV2.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlegiondominionrankingv2(_dominion_id INTEGER, _server_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	select legion_id, COALESCE(guild.race, 0), COALESCE(guild.master_id, 0), COALESCE(guild.emblem_img_version, 0), COALESCE(guild.emblem_bgcolor, 0), COALESCE(guild.name, 'unknown'), score, played_time_in_sec, game_end_time from legion_dominion_rankings LEFT OUTER JOIN guild on legion_id=guild.id where take_over_processed_time=0 and dominion_id=_dominion_id and server_id=_server_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionrankingv2;
-- +goose StatementEnd
