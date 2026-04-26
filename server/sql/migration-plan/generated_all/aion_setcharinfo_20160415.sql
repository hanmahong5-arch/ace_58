-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharInfo_20160415.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharinfo_20160415(_char_i_d INTEGER, _class INTEGER, _guild_id INTEGER, _guild_rank INTEGER, _recreate_guild_time INTEGER, _cur_server INTEGER, _world INTEGER, _world_map_number INTEGER, _xlocation DOUBLE PRECISION, _ylocation DOUBLE PRECISION, _zlocation DOUBLE PRECISION, _dir INTEGER, _last_normal_world INTEGER, _last_normal_xlocation DOUBLE PRECISION, _last_normal_ylocation DOUBLE PRECISION, _last_normal_zlocation DOUBLE PRECISION, _last_normal_dir INTEGER, _death_count INTEGER, _temporary_lost_exp BIGINT, _resurrect_world INTEGER, _resurrect_xlocation DOUBLE PRECISION, _resurrect_ylocation DOUBLE PRECISION, _resurrect_zlocation DOUBLE PRECISION, _hp INTEGER, _mp INTEGER, _fp INTEGER, _exp BIGINT, _abyss_point BIGINT, _abyss_point_from_user BIGINT, _level INTEGER, _stigma_point INTEGER, _cur_title_id INTEGER, _cur_title_attr_id INTEGER, _guild_intro TEXT, _guild_nick_name TEXT, _today_abyss_kill_cnt INTEGER, _today_abyss_point BIGINT, _this_week_abyss_kill_cnt INTEGER, _this_week_abyss_point BIGINT, _last_week_abyss_kill_cnt INTEGER, _last_week_abyss_point BIGINT, _total_abyss_kill_cnt INTEGER, _best_abyss_rank INTEGER, _freefly INTEGER, _optionflags INTEGER, _accused_count INTEGER, _last_accuse_time INTEGER, _bot_point INTEGER, _vital_point BIGINT, _pvp_exp BIGINT, _serial_kill_point INTEGER, _serial_kill_duration INTEGER, _serial_kill_penalty_skill_rank INTEGER, _enhanced_stigma_slot_cnt INTEGER, _housing_id INTEGER, _fatigue_resttime_online INTEGER, _next_hotspot_use_time BIGINT, _gotcha_fever_point INTEGER, _gotcha_fever_expire_time BIGINT, _gotcha_fever_hit_count INTEGER, _last_explicit_beginner_force INTEGER, _absolute_exp BIGINT, _serial_guard_point INTEGER, _serial_guard_last_scantime INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data 



SET 	class = _class,

	guild_id = _guild_id, guild_rank = _guild_rank, recreate_guild_time = _recreate_guild_time,

	cur_server = _cur_server, world = _world, world_map_number = _world_map_number, xlocation = _xlocation, ylocation = _ylocation, zlocation = _zlocation, dir = _dir,	

	last_normal_world = _last_normal_world, last_normal_xlocation = _last_normal_xlocation, 

	last_normal_ylocation = _last_normal_ylocation, last_normal_zlocation = _last_normal_zlocation, last_normal_dir = (_last_normal_dir % 120),

	death_count = _death_count, temporary_lost_exp = _temporary_lost_exp,

	resurrect_world = _resurrect_world, resurrect_xlocation = _resurrect_xlocation, resurrect_ylocation = _resurrect_ylocation, resurrect_zlocation = _resurrect_zlocation,

	now_hit = _hp, now_mana = _mp, now_flight = _fp, exp = _exp, abyss_point = _abyss_point, abyss_point_from_user = _abyss_point_from_user,

	lev = _level, stigmaPoint = _stigma_point,

	cur_title_id=_cur_title_id, cur_title_attr_id=_cur_title_attr_id,

	guild_intro = _guild_intro,	 guild_nickname = _guild_nick_name,

	today_abyss_kill_cnt = _today_abyss_kill_cnt, today_abyss_point = _today_abyss_point,

	this_week_abyss_kill_cnt = _this_week_abyss_kill_cnt, this_week_abyss_point = _this_week_abyss_point,

	last_week_abyss_kill_cnt = _last_week_abyss_kill_cnt, last_week_abyss_point = _last_week_abyss_point,

	total_abyss_kill_cnt = _total_abyss_kill_cnt, best_abyss_rank = _best_abyss_rank, is_freefly = _freefly,

	optionflags = _optionflags, accused_count = _accused_count, last_accuse_time = _last_accuse_time,

	bot_point = _bot_point, vital_point = _vital_point, pvp_exp = _pvp_exp,

	serial_kill_point = _serial_kill_point, serial_kill_penalty_duration = _serial_kill_duration, serial_kill_penalty_skill_rank = _serial_kill_penalty_skill_rank,

	enhanced_stigma_slot_cnt = _enhanced_stigma_slot_cnt,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0),

	housing_id = _housing_id,

	fatigue_resttime_online = _fatigue_resttime_online,

	next_hotspot_use_time = _next_hotspot_use_time,

	gotcha_fever_point = _gotcha_fever_point,

	gotcha_fever_expire_time = _gotcha_fever_point,

	gotcha_fever_hit_count = _gotcha_fever_hit_count,

	last_explicit_beginner_force = _last_explicit_beginner_force,

	absolute_exp = _absolute_exp,

	serial_guard_point = _serial_guard_point, serial_guard_last_scantime = _serial_guard_last_scantime

WHERE char_id  =  _char_i_d;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharinfo_20160415;
-- +goose StatementEnd
