-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemListEnchant_20160122.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemlistenchant_20160122(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	ID, COALESCE(soul_bound, 0), COALESCE(enchant_count, 0), COALESCE(skin_name_id, 0), COALESCE(wardrobeSlotId, 0),

COALESCE(stat_enchant_name0, 0), 

	COALESCE(stat_enchant_name1, 0), 

	COALESCE(stat_enchant_name2, 0), 

	COALESCE(stat_enchant_name3, 0), 

	COALESCE(stat_enchant_name4, 0), 

	COALESCE(stat_enchant_name5, 0),  COALESCE(option_count,0), COALESCE(dye_info,0), COALESCE(proc_tool_nameId, 0), 

	COALESCE(obtain_skin_type, 0), COALESCE(expire_skin_time,0), COALESCE(expire_dye_time,0) as expire_dye_time, COALESCE(random_option,0) as random_option, 

	COALESCE(limit_enchant_count,0) as limit_enchant_count, COALESCE(reidentify_count, 0) as reidentify_count,

	COALESCE(authorize_count, 0) as authorize_count, COALESCE(vanish_point,0) as vanish_point,	

	COALESCE(enchant_prob_addition, 0),

	COALESCE(option_prob_addition, 0),

	COALESCE(proc_break_count, 0),

	COALESCE(proc_break_flag, 0),

	COALESCE(keyNameId, 0),

	COALESCE(exceedState, 0),

	COALESCE(exceedSkillId1, 0),

	COALESCE(exceedSkillId2, 0),

	COALESCE(exceedSkillId3, 0),

	COALESCE(baseSkillId, 0),

	COALESCE(enhanceSkillGroup, 0),

	COALESCE(enhanceSkillLevel, 0),

	COALESCE(equipLevelDown, 0)

from	user_item_option (nolock)

where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlistenchant_20160122;
-- +goose StatementEnd
