-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetPollList_150301.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpolllist_150301(_curr_time INTEGER, _poll_version INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select poll_id, base_poll_id, status , priority, start_time, end_time, race_restriction, class_restriction, reward_item_count, 

	level_restriction, world_restriction, reward, contents_size, contents, abysspoint_restriction, item_restriction, 

	quest_restriction, region_restriction, quest_state_restriction, quest_condition_restriction, 

	bmAccountType_restriction, bmPackType_restriction, inter_server_type, promtion_target_restriction

	,COALESCE(vip_grade_restriction, '') as vip_grade_restriction, game_exprience_lv_restriction

	

from poll_info

where (status = 2 or status = 4) and _curr_time <= end_time and poll_version = _poll_version;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpolllist_150301;
-- +goose StatementEnd
