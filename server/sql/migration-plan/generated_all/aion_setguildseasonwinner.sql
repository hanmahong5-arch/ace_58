-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildSeasonWinner.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildseasonwinner(_winner_light INTEGER, _winner_dark INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update abyss_reward_update_time set guild_winner_light = _winner_light, guild_winner_dark = _winner_dark

	if (@_r_o_w_c_o_u_n_t = 0)

	begin

		insert into abyss_reward_update_time (guild_winner_light, guild_winner_dark) values (_winner_light, _winner_dark)

	end

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildseasonwinner;
-- +goose StatementEnd
