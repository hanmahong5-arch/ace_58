-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutPollInfo_150727.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putpollinfo_150727(_poll_id INTEGER, _base_poll_id INTEGER, _status INTEGER, _priority INTEGER, _start_time INTEGER, _end_time INTEGER, _race_restriction INTEGER, _class_restriction INTEGER, _reward_item_count INTEGER, _level_restriction TEXT, _world_restriction TEXT, _reward TEXT, _abyss_point_restriction TEXT, _item_restriction TEXT, _quest_restriction TEXT, _region_restriction TEXT, _contents_size INTEGER, _contents TEXT, _version INTEGER, _quest_state_restriction INTEGER, _quest_condition_restriction INTEGER, _bm_account_type_restriction TEXT, _bm_pack_type_restriction TEXT, _inter_svr_type INTEGER, _promtion_target_restriction INTEGER, _grade_restriction TEXT, _game_exprience_lv_restriction INTEGER, _playtime_restriction INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
insert into poll_info (poll_Id, base_poll_id, status, priority, start_time, end_time, race_restriction, class_restriction, 

	reward_item_count, level_restriction, world_restriction, reward, contents_size, contents, abysspoint_restriction, 

	item_restriction, quest_restriction, region_restriction, poll_version, quest_state_restriction, quest_condition_restriction,

	bmAccountType_restriction, bmPackType_restriction, inter_server_type, promtion_target_restriction

	,vip_grade_restriction, game_exprience_lv_restriction, playtime_restriction

	)

values (_poll_id, _base_poll_id, _status, _priority, _start_time, _end_time, _race_restriction, _class_restriction, 

	_reward_item_count, _level_restriction, _world_restriction, _reward, _contents_size, _contents, _abyss_point_restriction, 

	_item_restriction, _quest_restriction, _region_restriction, _version, _quest_state_restriction, _quest_condition_restriction,

	_bm_account_type_restriction, _bm_pack_type_restriction, _inter_svr_type, _promtion_target_restriction

	, _grade_restriction, _game_exprience_lv_restriction, _playtime_restriction

	);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpollinfo_150727;
-- +goose StatementEnd
