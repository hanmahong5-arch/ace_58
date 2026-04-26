-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemEnchant_20180209.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemenchant_20180209(_itemid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	ID, soul_bound, enchant_count, skin_name_id, wardrobeSlotId,

	stat_enchant_name0,

	stat_enchant_name1,

	stat_enchant_name2, 

	stat_enchant_name3,

	stat_enchant_name4, 

	stat_enchant_name5, option_count, dye_info, proc_tool_nameId, 

	obtain_skin_type, expire_skin_time, COALESCE(expire_dye_time, 0) as expire_dye_time, COALESCE(random_option,0) as random_option,

	COALESCE(limit_enchant_count, 0) as limit_enchant_count,

	COALESCE(reidentify_count, 0) as reidentify_count,	

	COALESCE(authorize_count, 0) as authorize_count,

	COALESCE(vanish_point, 0) as vanish_point,	

	COALESCE(enchant_prob_addition, 0), COALESCE(option_prob_addition, 0),

	COALESCE(proc_break_count, 0), COALESCE(proc_break_flag, 0),

	COALESCE(keyNameId, 0),

	COALESCE(exceedState, 0),

	COALESCE(exceedSkillId1, 0),

	COALESCE(exceedSkillId2, 0),

	COALESCE(exceedSkillId3, 0),

	COALESCE(baseSkillId, 0),

	COALESCE(enhanceSkillGroup, 0),

	COALESCE(enhanceSkillLevel, 0),

	COALESCE(equipLevelDown, 0),

	COALESCE(randomAttr1, 0), COALESCE(randomValue1, 0),

	COALESCE(randomAttr2, 0), COALESCE(randomValue2, 0),

	COALESCE(randomAttr3, 0), COALESCE(randomValue3, 0),

	COALESCE(randomAttr4, 0), COALESCE(randomValue4, 0),

	COALESCE(randomAttr5, 0), COALESCE(randomValue5, 0),

	COALESCE(randomAttr6, 0), COALESCE(randomValue6, 0),

	COALESCE(randomAttr7, 0), COALESCE(randomValue7, 0),

	COALESCE(randomAttr8, 0), COALESCE(randomValue8, 0),

	COALESCE(randomAttr9, 0), COALESCE(randomValue9, 0),

	COALESCE(randomAttr10, 0), COALESCE(randomValue10, 0)

from	user_item_option (nolock)

where	id = _itemid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemenchant_20180209;
-- +goose StatementEnd
