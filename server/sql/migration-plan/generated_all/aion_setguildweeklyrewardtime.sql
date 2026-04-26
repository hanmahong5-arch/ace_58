-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildWeeklyRewardTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildweeklyrewardtime(_week_reward_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update abyss_reward_update_time set guild_week_reward_time = _week_reward_time

	if (@_r_o_w_c_o_u_n_t = 0)

	begin

		insert into abyss_reward_update_time (guild_week_reward_time) values (_week_reward_time)

	end

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildweeklyrewardtime;
-- +goose StatementEnd
