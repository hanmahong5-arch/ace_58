-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_LoadLegionDominionOwnerInfoV2.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlegiondominionownerinfov2(_lastest_take_over_time BIGINT, _server_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	select dominion_id, legion_id, COALESCE(guild.race, 0), COALESCE(guild.master_id, 0), COALESCE(guild.emblem_img_version, 0), COALESCE(guild.emblem_bgcolor, 0), COALESCE(guild.name, 'unknown') from (

		select ROW_NUMBER() over (partition by dominion_id order by score desc, played_time_in_sec asc, game_end_time asc) as row, dominion_id, legion_id from legion_dominion_rankings where dominion_id<>0 and take_over_processed_time=_lastest_take_over_time

	) as results LEFT OUTER JOIN guild ON results.legion_id = guild.id where results.row=1

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionownerinfov2;
-- +goose StatementEnd
