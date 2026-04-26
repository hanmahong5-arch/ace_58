-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildSeasonRewardTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildseasonrewardtime(_season_reward_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update abyss_reward_update_time set guild_season_reward_time = _season_reward_time

	if (@_r_o_w_c_o_u_n_t = 0)

	begin

		insert into abyss_reward_update_time (guild_season_reward_time) values (_season_reward_time)

	end

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildseasonrewardtime;
-- +goose StatementEnd
