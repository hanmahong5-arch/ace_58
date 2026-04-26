-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildRewardTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildrewardtime()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	declare _week_reward_time bigint

	declare _season_reward_time bigint

	declare _winner_light int

	declare _winner_dark int

	

	SELECT guild_week_reward_time, 

				 _season_reward_time = guild_season_reward_time, 

				 _winner_light = guild_winner_light,

				 _winner_dark  = guild_winner_dark INTO _week_reward_time

	from abyss_reward_update_time

	

	select COALESCE(_week_reward_time, 0), COALESCE(_season_reward_time, 0), COALESCE(_winner_light, 0), COALESCE(_winner_dark, 0)

end /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildrewardtime;
-- +goose StatementEnd
