-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutItem_20180615.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putitem_20180615(_id BIGINT, _char_id INTEGER, _name_id INTEGER, _slot_id INTEGER, _amount BIGINT, _tid BIGINT, _slot_num INTEGER, _warehouse INTEGER, _soul_bound INTEGER, _enchant_count INTEGER, _skin_name_id INTEGER, _stat_enchant_name0 INTEGER, _stat_enchant_name1 INTEGER, _stat_enchant_name2 INTEGER, _stat_enchant_name3 INTEGER, _stat_enchant_name4 INTEGER, _stat_enchant_name5 INTEGER, _option_count INTEGER, _dye_info INTEGER, _proc_tool_name_id INTEGER, _expired_time INTEGER, _producer TEXT, _buyamount INTEGER, _buyduration INTEGER, _obtain_skin_type INTEGER, _expire_skin_time INTEGER, _dynamic_property INTEGER, _server_of_origin INTEGER, _expire_dye_time INTEGER, _random_option INTEGER, _limit_enchant_count INTEGER, _reidentify_count INTEGER, _authorize_count INTEGER, _vanish_point INTEGER, _enchant_prob_addition INTEGER, _option_prob_addition INTEGER, _name_id INTEGER, _exceed_state INTEGER, _exceed_skill_id1 INTEGER, _exceed_skill_id2 INTEGER, _exceed_skill_id3 INTEGER, _base_skill_id INTEGER, _enhance_skill_group INTEGER, _enhance_skill_level INTEGER, _equip_level_down INTEGER, _random_attr1 INTEGER, _random_value1 INTEGER, _random_attr2 INTEGER, _random_value2 INTEGER, _random_attr3 INTEGER, _random_value3 INTEGER, _random_attr4 INTEGER, _random_value4 INTEGER, _random_attr5 INTEGER, _random_value5 INTEGER, _random_attr6 INTEGER, _random_value6 INTEGER, _random_attr7 INTEGER, _random_value7 INTEGER, _random_attr8 INTEGER, _random_value8 INTEGER, _random_attr9 INTEGER, _random_value9 INTEGER, _random_attr10 INTEGER, _random_value10 INTEGER, _skill_skin_name_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_item (char_id, name_id, slot_id, amount,tid,slot,warehouse,

		producer, expired_time,buy_amount, buy_duration,

		dynamic_property, server_of_origin)

VALUES (_char_id, _name_id, _slot_id, _amount, _tid, _slot_num, _warehouse,

		_producer, _expired_time, _buyamount, _buyduration,

		_dynamic_property, _server_of_origin)



IF @_e_r_r_o_r <> 0

	return

_id := @_i_d_e_n_t_i_t_y



--if (_stat_enchant_name0 + _stat_enchant_name1+_stat_enchant_name2 + _stat_enchant_name3 + _stat_enchant_name4+_stat_enchant_name5+_enchant_count+_soul_bound + _option_count + _dye_info + _limit_enchant_count > 0 )

if (

	(_random_option > 0) or (_skin_name_id > 0) or (_stat_enchant_name0 > 0) or (_stat_enchant_name1 > 0) or (_stat_enchant_name2 > 0) or (_stat_enchant_name3 > 0) 

	or (_stat_enchant_name4 > 0) or (_stat_enchant_name5 > 0) or (_proc_tool_name_id > 0) or (_enchant_count > 0) or (_soul_bound > 0) or (_option_count > 0) or (_dye_info != 0) 

	or (_limit_enchant_count > 0) or (_authorize_count > 0) or (_vanish_point > 0) or (_enchant_prob_addition > 0) or (_option_prob_addition > 0) or (_name_id > 0)

	)

begin

insert user_item_option (id, char_id, soul_bound, enchant_count, skin_name_id, 

		stat_enchant_name0, stat_enchant_name1, stat_enchant_name2, 

		stat_enchant_name3, stat_enchant_name4, stat_enchant_name5, 

		option_count, dye_info, proc_tool_nameid, obtain_skin_type, expire_skin_time,

		expire_dye_time, random_option, limit_enchant_count, reidentify_count,

		authorize_count, vanish_point, 		

		enchant_prob_addition, option_prob_addition,

		KeyNameId, exceedState, ExceedSkillId1, ExceedSkillId2, ExceedSkillId3,

		BaseSkillId, enhanceSkillGroup, enhanceSkillLevel, equipleveldown, 

		randomAttr1, randomAttr2 ,randomAttr3,randomAttr4,randomAttr5,randomAttr6,randomAttr7,randomAttr8,randomAttr9,randomAttr10,

		randomValue1, randomValue2 ,randomValue3,randomValue4,randomValue5,randomValue6,randomValue7,randomValue8,randomValue9,randomValue10,

		skill_skin_name_Id

		)

		values

		(_id, _char_id,_soul_bound,_enchant_count,_skin_name_id, 

		_stat_enchant_name0, _stat_enchant_name1,

		_stat_enchant_name2, _stat_enchant_name3,

		_stat_enchant_name4, _stat_enchant_name5,

		_option_count, _dye_info, _proc_tool_name_id,_obtain_skin_type, _expire_skin_time,

		_expire_dye_time, _random_option,_limit_enchant_count, _reidentify_count,

		_authorize_count, _vanish_point,		

		_enchant_prob_addition, _option_prob_addition,

		_name_id, _exceed_state, _exceed_skill_id1, _exceed_skill_id2, _exceed_skill_id3,

		_base_skill_id, _enhance_skill_group, _enhance_skill_level, _equip_level_down,

		_random_attr1, _random_attr2, _random_attr3, _random_attr4, _random_attr5, _random_attr6, _random_attr7, _random_attr8, _random_attr9, _random_attr10,

		_random_value1, _random_value2, _random_value3, _random_value4, _random_value5, _random_value6, _random_value7, _random_value8, _random_value9, _random_value10,

		_skill_skin_name_id

		)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putitem_20180615;
-- +goose StatementEnd
