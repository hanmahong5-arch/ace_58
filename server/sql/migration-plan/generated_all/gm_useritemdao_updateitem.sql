-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updateitem(_id BIGINT, _char_id INTEGER, _amount BIGINT, _warehouse INTEGER, _enchant_count INTEGER, _stat_enchant_name0 INTEGER, _stat_enchant_name1 INTEGER, _stat_enchant_name2 INTEGER, _stat_enchant_name3 INTEGER, _stat_enchant_name4 INTEGER, _stat_enchant_name5 INTEGER, _option_count INTEGER, _dye_info INTEGER, _proc_tool_nameid INTEGER, _skin_name_id INTEGER, _random_option INTEGER, _authorize_count INTEGER, _vanish_point INTEGER, _exceed_state INTEGER, _exceed_skill_id1 INTEGER, _exceed_skill_id2 INTEGER, _exceed_skill_id3 INTEGER, _base_skill_id INTEGER, _enhance_skill_group INTEGER, _enhance_skill_level INTEGER, _equip_level_down INTEGER, _random_attr1 INTEGER, _random_value1 INTEGER, _random_attr2 INTEGER, _random_value2 INTEGER, _random_attr3 INTEGER, _random_value3 INTEGER, _random_attr4 INTEGER, _random_value4 INTEGER, _random_attr5 INTEGER, _random_value5 INTEGER, _random_attr6 INTEGER, _random_value6 INTEGER, _random_attr7 INTEGER, _random_value7 INTEGER, _random_attr8 INTEGER, _random_value8 INTEGER, _random_attr9 INTEGER, _random_value9 INTEGER, _random_attr10 INTEGER, _random_value10 INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

			-- user_item

			UPDATE	user_item

			SET		amount				= _amount

					, warehouse			= _warehouse

			WHERE	id = _id and char_id = _char_id



			-- user_item_option

			UPDATE	user_item_option

			SET		enchant_count			= _enchant_count

					, stat_enchant_name0	= _stat_enchant_name0

					, stat_enchant_name1	= _stat_enchant_name1

					, stat_enchant_name2	= _stat_enchant_name2

					, stat_enchant_name3	= _stat_enchant_name3

					, stat_enchant_name4	= _stat_enchant_name4

					, stat_enchant_name5	= _stat_enchant_name5

					, option_count			= _option_count

					, dye_info				= _dye_info

					, proc_tool_nameid		= _proc_tool_nameid

					, skin_name_id			= _skin_name_id

					, random_option			= _random_option

					, authorize_count		= _authorize_count

					, vanish_point			= _vanish_point

					, exceedState			= _exceed_state

					, exceedSkillId1		= _exceed_skill_id1

					, exceedSkillId2		= _exceed_skill_id2

					, exceedSkillId3		= _exceed_skill_id3

					, baseSkillId			= _base_skill_id

					, enhanceSkillGroup		= _enhance_skill_group

					, enhanceSkillLevel		= _enhance_skill_level

					, equipLevelDown		= _equip_level_down

					, randomAttr1			= _random_attr1, randomValue1			= _random_value1

					, randomAttr2			= _random_attr2, randomValue2			= _random_value2

					, randomAttr3			= _random_attr3, randomValue3			= _random_value3

					, randomAttr4			= _random_attr4, randomValue4			= _random_value4

					, randomAttr5			= _random_attr5, randomValue5			= _random_value5

					, randomAttr6			= _random_attr6, randomValue6			= _random_value6

					, randomAttr7			= _random_attr7, randomValue7			= _random_value7

					, randomAttr8			= _random_attr8, randomValue8			= _random_value8

					, randomAttr9			= _random_attr9, randomValue9			= _random_value9

					, randomAttr10			= _random_attr10, randomValue10			= _random_value10

			WHERE	id = _id and char_id = _char_id



			-- user_item_option row가 없으면 insert

			if @_r_o_w_c_o_u_n_t = 0

			INSERT	user_item_option (id, char_id, enchant_count, skin_name_id, soul_bound, 

					stat_enchant_name0, stat_enchant_name1, stat_enchant_name2, stat_enchant_name3, stat_enchant_name4, stat_enchant_name5, 

					option_count, dye_info, proc_tool_nameid, obtain_skin_type, expire_skin_time, expire_dye_time, random_option, authorize_count, vanish_point

					, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, equipLevelDown

					, randomAttr1, randomValue1, randomAttr2, randomValue2, randomAttr3, randomValue3, randomAttr4, randomValue4, randomAttr5, randomValue5

					, randomAttr6, randomValue6, randomAttr7, randomValue7, randomAttr8, randomValue8, randomAttr9, randomValue9, randomAttr10, randomValue10)

			VALUES	(_id, _char_id, _enchant_count, _skin_name_id, 0, 

					_stat_enchant_name0, _stat_enchant_name1, _stat_enchant_name2, _stat_enchant_name3, _stat_enchant_name4, _stat_enchant_name5, 

					_option_count, _dye_info, _proc_tool_nameid, 0, 0, 0, _random_option, _authorize_count, _vanish_point

					, _exceed_state, _exceed_skill_id1, _exceed_skill_id2, _exceed_skill_id3, _base_skill_id, _enhance_skill_group, _enhance_skill_level, _equip_level_down

					, _random_attr1, _random_value1, _random_attr2, _random_value2, _random_attr3, _random_value3, _random_attr4, _random_value4, _random_attr5, _random_value5

					, _random_attr6, _random_value6, _random_attr7, _random_value7, _random_attr8, _random_value8, _random_attr9, _random_value9, _random_attr10, _random_value10)

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updateitem;
-- +goose StatementEnd
