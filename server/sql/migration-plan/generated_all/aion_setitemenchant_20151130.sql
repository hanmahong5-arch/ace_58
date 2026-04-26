-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemEnchant_20151130.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemenchant_20151130(_id BIGINT, _soul_bound INTEGER, _enchant_count INTEGER, _skin_name_id INTEGER, _wardrobe_slot_id INTEGER, _stat_enchant_name0 INTEGER, _stat_enchant_name1 INTEGER, _stat_enchant_name2 INTEGER, _stat_enchant_name3 INTEGER, _stat_enchant_name4 INTEGER, _stat_enchant_name5 INTEGER, _proc_tool_name_id INTEGER, _obtain_skin_type INTEGER, _expire_skin_time INTEGER, _limit_enchant_count INTEGER, _authorize_count INTEGER, _vanish_point INTEGER, _enchant_prob_addition INTEGER, _option_prob_addition INTEGER, _name_id INTEGER, _exceed_state INTEGER, _exceed_skill_id1 INTEGER, _exceed_skill_id2 INTEGER, _exceed_skill_id3 INTEGER, _base_skill_id INTEGER, _enhance_skill_group INTEGER, _enhance_skill_level INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _char_id int

declare _main_item_id bigint



if (_enchant_count = 0) --보조무기이고, enchant가 0으로 오면, 기존 enchant값을 유지한다.

begin 

	SELECT COALESCE(main_item_dbid, 0)from user_item with (nolock) where id = _id 

	

	if (_main_item_id > 0) --적어도 메인 아이템이 있다면, enchant도 있을 것이다.

	begin

		select _enchant_count = COALESCE(enchant_count, 0) INTO _main_item_id from user_item_option with (nolock)  where id=_id

	end

end




UPDATE user_item_option

SET soul_bound = _soul_bound, enchant_count = _enchant_count, skin_name_id = _skin_name_id, wardrobeSlotId = _wardrobe_slot_id,

	stat_enchant_name0 = _stat_enchant_name0,

	stat_enchant_Name1 = _stat_enchant_name1,

	stat_enchant_Name2 = _stat_enchant_name2,

	stat_enchant_Name3 = _stat_enchant_name3,

	stat_enchant_Name4 = _stat_enchant_name4,

	stat_enchant_Name5 = _stat_enchant_name5,		

	proc_tool_nameid = _proc_tool_name_id, 

	obtain_skin_type = _obtain_skin_type, expire_skin_time = _expire_skin_time,

	limit_enchant_count = _limit_enchant_count,

	authorize_count = _authorize_count, vanish_point=_vanish_point,	

	enchant_prob_addition = _enchant_prob_addition,

	option_prob_addition = _option_prob_addition,

	KeyNameId = _name_id,

	exceedState = _exceed_state,

	exceedSkillId1 = _exceed_skill_id1, 

	exceedSkillId2 = _exceed_skill_id2, 

	exceedSkillId3 = _exceed_skill_id3,

	baseSkillId = _base_skill_id,

	enhanceSkillGroup = _enhance_skill_group,

	enhanceSkillLevel = _enhance_skill_level

WHERE id=_id





if @_r_o_w_c_o_u_n_t = 0

begin

	select _char_id = char_id  from user_item where id = _id

	

	insert user_item_option (id, char_id, soul_bound, enchant_count, skin_name_id, wardrobeSlotId,

			stat_enchant_name0, stat_enchant_Name1, 

			stat_enchant_Name2, stat_enchant_Name3, 

			stat_enchant_Name4, stat_enchant_Name5, 

			proc_tool_nameid, 

			obtain_skin_type, expire_skin_time, limit_enchant_count, 

			authorize_count, vanish_point,			

			enchant_prob_addition, option_prob_addition,

			KeyNameId, exceedState, ExceedSkillId1, ExceedSkillId2, ExceedSkillId3,

			baseSkillId, enhanceSkillGroup, enhanceSkillLevel

			)

			values

			(_id, _char_id,_soul_bound,_enchant_count,_skin_name_id, _wardrobe_slot_id,

			_stat_enchant_name0, _stat_enchant_name1,

			_stat_enchant_name2, _stat_enchant_name3,

			_stat_enchant_name4, _stat_enchant_name5,

			_proc_tool_name_id,

			_obtain_skin_type, _expire_skin_time,

			_limit_enchant_count,

			_authorize_count, _vanish_point,			

			_enchant_prob_addition, _option_prob_addition,

			_name_id, _exceed_state, _exceed_skill_id1, _exceed_skill_id2, _exceed_skill_id3,

			_base_skill_id, _enhance_skill_group, _enhance_skill_level

			)

	if @_e_r_r_o_r <> 0

	begin

		UPDATE user_item_option

		SET soul_bound = _soul_bound, enchant_count = _enchant_count, skin_name_id = _skin_name_id,

			wardrobeSlotId = _wardrobe_slot_id,

			stat_enchant_name0 = _stat_enchant_name0,

			stat_enchant_Name1 = _stat_enchant_name1,

			stat_enchant_Name2 = _stat_enchant_name2,

			stat_enchant_Name3 = _stat_enchant_name3,

			stat_enchant_Name4 = _stat_enchant_name4,

			stat_enchant_Name5 = _stat_enchant_name5,		

			proc_tool_nameid = _proc_tool_name_id, 

			obtain_skin_type = _obtain_skin_type, expire_skin_time = _expire_skin_time,

			limit_enchant_count = _limit_enchant_count,

			authorize_count = _authorize_count, vanish_point=_vanish_point,			

			enchant_prob_addition = _enchant_prob_addition,

			option_prob_addition = _option_prob_addition, 

			KeyNameId = _name_id,

			exceedState = _exceed_state,

			exceedSkillId1 = _exceed_skill_id1, 

			exceedSkillId2 = _exceed_skill_id2, 

			exceedSkillId3 = _exceed_skill_id3,

			baseSkillId = _base_skill_id,

			enhanceSkillGroup = _enhance_skill_group,

			enhanceSkillLevel = _enhance_skill_level			

		WHERE id=_id

	end

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemenchant_20151130;
-- +goose StatementEnd
