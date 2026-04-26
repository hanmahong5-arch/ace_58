-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetAllAbyssInfoNew_20140401.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getallabyssinfonew_20140401()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT abyss_id, owner_server, owner_guild, owner_char_id, owner_race, defense_count, reward, occupy_bonus, user_reward_sum, change_owner_time, COALESCE(guild.name, '') as guild_name, COALESCE(guild.emblem_img_version, 0) as guild_emblem_ver, COALESCE(guild.emblem_bgcolor, 0) as guild_emblem_bgcolor,

cur_pvp_status, next_pvp_status, door_upgrade_point, shield_upgrade_point, peace_count, occupy_point, occupy_count

FROM abyss LEFT OUTER JOIN guild ON abyss.owner_guild = guild.id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getallabyssinfonew_20140401;
-- +goose StatementEnd
