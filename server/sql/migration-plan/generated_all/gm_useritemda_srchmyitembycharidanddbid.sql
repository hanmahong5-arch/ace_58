-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchMyItemByCharIDandDBID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyitembycharidanddbid(_char_id TEXT, _db_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			SELECT  i.id, i.char_id, i.name_id

					, slot_id, amount, slot, warehouse, convert(nvarchar,create_date,21) create_date, convert(nvarchar,update_date,21) update_date, producer, tid, expired_time, buy_amount, buy_duration, main_item_dbid, dynamic_property

					, option_count, soul_bound, enchant_count, skin_name_id, stat_enchant_name0, stat_enchant_name1, stat_enchant_name2, stat_enchant_name3, stat_enchant_name4, stat_enchant_name5, option_count, dye_info, proc_tool_nameid, obtain_skin_type, expire_skin_time, expire_dye_time, COALESCE(random_option,0) AS random_option, COALESCE(limit_enchant_count,0) AS limit_enchant_count

					, COALESCE(reidentify_count,0) AS reidentify_count

					, COALESCE(freetradestate, 0) as freetradestate

					, COALESCE(authorize_count, 0) as authorize_count, COALESCE(vanish_point, 0) as vanish_point

					-- 4.5 17차 깃털

					, COALESCE(attribute1, 0) as attribute1, COALESCE(attribute1value, 0) as attribute1value, COALESCE(attribute2, 0) as attribute2, COALESCE(attribute2value, 0) as attribute2value, COALESCE(attribute3, 0) as attribute3, COALESCE(attribute3value, 0) as attribute3value, COALESCE(attribute4, 0) as attribute4, COALESCE(attribute4value, 0) as attribute4value, COALESCE(attribute5, 0) as attribute5, COALESCE(attribute5value, 0) as attribute5value, COALESCE(attribute6, 0) as attribute6, COALESCE(attribute6value, 0) as attribute6value

					-- [4.71] 모조신석

					, COALESCE(proc_break_count, 0) as proc_break_count, COALESCE(proc_break_flag, 0) as proc_break_flag

					-- [4.75] 돌파스킬

					, COALESCE(exceedState, 0) as exceedState, COALESCE(exceedSkillId1, 0) as exceedSkillId1, COALESCE(exceedSkillId2, 0) as exceedSkillId2, COALESCE(exceedSkillId3, 0) as exceedSkillId3

					-- [4.9] 최강무기 스킬

					, COALESCE(baseSkillId, 0) as baseSkillId

					-- [5.0] 아이템으로 스킬 강화

					, COALESCE(enhanceSkillGroup, 0) as enhanceSkillGroup, COALESCE(enhanceSkillLevel, 0) as enhanceSkillLevel

					-- [5.0] 아이템 레벨 다운

					, COALESCE(equipLevelDown, 0) as equipLevelDown

					, COALESCE(wardrobeSlotId, 0) as wardrobeSlotId

					-- [6.2] 아이템 랜덤 옵션 (새로운 것)

					, COALESCE(randomAttr1, 0) as randomAttr1, COALESCE(randomValue1, 0) as randomValue1, COALESCE(randomAttr2, 0) as randomAttr2, COALESCE(randomValue2, 0) as randomValue2, COALESCE(randomAttr3, 0) as randomAttr3, COALESCE(randomValue3, 0) as randomValue3, COALESCE(randomAttr4, 0) as randomAttr4, COALESCE(randomValue4, 0) as randomValue4, COALESCE(randomAttr5, 0) as randomAttr5, COALESCE(randomValue5, 0) as randomValue5

					, COALESCE(randomAttr6, 0) as randomAttr6, COALESCE(randomValue6, 0) as randomValue6, COALESCE(randomAttr7, 0) as randomAttr7, COALESCE(randomValue7, 0) as randomValue7, COALESCE(randomAttr8, 0) as randomAttr8, COALESCE(randomValue8, 0) as randomValue8, COALESCE(randomAttr9, 0) as randomAttr9, COALESCE(randomValue9, 0) as randomValue9, COALESCE(randomAttr10, 0) as randomAttr10, COALESCE(randomValue10, 0) as randomValue10

			FROM	user_item i (nolock)

			LEFT JOIN user_item_option o (nolock) ON i.id = o.id and o.char_id = i.char_id

			LEFT JOIN user_item_freeTrade f (nolock) on i.id = f.id

			LEFT JOIN user_item_attribute a (nolock) on i.id = a.id

			WHERE	i.char_id = _char_id and i.id = _db_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchmyitembycharidanddbid;
-- +goose StatementEnd
