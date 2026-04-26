-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchMyChargedItems.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchmychargeditems(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off



			SELECT	-- user_item (메인무기)

					i1.id, i1.char_id, i1.name_id, i1.slot_id, i1.amount, i1.slot, i1.warehouse, convert(nvarchar,i1.create_date,21 ) AS create_date, convert(nvarchar,i1.update_date,21 ) AS update_date, i1.producer, i1.tid, i1.expired_time, i1.buy_amount, i1.buy_duration, i1.main_item_dbid, i1.dynamic_property, i1.import_id, i1.export_id, i1.server_of_origin

					-- user_item_option

					, o1.soul_bound, o1.enchant_count, o1.skin_name_id, o1.stat_enchant_name0, o1.stat_enchant_name1, o1.stat_enchant_name2, o1.stat_enchant_name3, o1.stat_enchant_name4, o1.stat_enchant_name5, o1.option_count, o1.dye_info, o1.proc_tool_nameid, o1.obtain_skin_type, o1.expire_skin_time, o1.expire_dye_time, COALESCE(o1.random_option,0) AS random_option

					, COALESCE(o1.limit_enchant_count,0) AS limit_enchant_count, COALESCE(o1.reidentify_count,0) AS reidentify_count

					, COALESCE(freetradestate, 0) as freetradestate

					, COALESCE(authorize_count, 0) as authorize_count, COALESCE(vanish_point, 0) as vanish_point

					-- 4.5 17차 깃털

					, COALESCE(attribute1, 0) as attribute1, COALESCE(attribute1value, 0) as attribute1value, COALESCE(attribute2, 0) as attribute2, COALESCE(attribute2value, 0) as attribute2value, COALESCE(attribute3, 0) as attribute3, COALESCE(attribute3value, 0) as attribute3value, COALESCE(attribute4, 0) as attribute4, COALESCE(attribute4value, 0) as attribute4value, COALESCE(attribute5, 0) as attribute5, COALESCE(attribute5value, 0) as attribute5value, COALESCE(attribute6, 0) as attribute6, COALESCE(attribute6value, 0) as attribute6value

					-- [4.71] 모조신석

					, COALESCE(proc_break_count, 0) as proc_break_count, COALESCE(proc_break_flag, 0) as proc_break_flag

					-- [4.75] 돌파스킬

					, COALESCE(exceedState, 0) as exceedState, COALESCE(exceedSkillId1, 0) as exceedSkillId1, COALESCE(exceedSkillId2, 0) as exceedSkillId2, COALESCE(exceedSkillId3, 0) as exceedSkillId3

					-- [4.9] 최강무기스킬

					, COALESCE(baseSkillId, 0) as baseSkillId

					-- [5.0] 아이템으로 스킬 강화

					, COALESCE(enhanceSkillGroup, 0) as enhanceSkillGroup, COALESCE(enhanceSkillLevel, 0) as enhanceSkillLevel

					-- [5.0] 아이템 레벨 다운

					, COALESCE(equipLevelDown, 0) as equipLevelDown

					, COALESCE(wardrobeSlotId, 0) as wardrobeSlotId

					-- [6.2] 아이템 랜덤 옵션 (새로운 것)

					, COALESCE(randomAttr1, 0) as randomAttr1, COALESCE(randomValue1, 0) as randomValue1, COALESCE(randomAttr2, 0) as randomAttr2, COALESCE(randomValue2, 0) as randomValue2, COALESCE(randomAttr3, 0) as randomAttr3, COALESCE(randomValue3, 0) as randomValue3, COALESCE(randomAttr4, 0) as randomAttr4, COALESCE(randomValue4, 0) as randomValue4, COALESCE(randomAttr5, 0) as randomAttr5, COALESCE(randomValue5, 0) as randomValue5

					, COALESCE(randomAttr6, 0) as randomAttr6, COALESCE(randomValue6, 0) as randomValue6, COALESCE(randomAttr7, 0) as randomAttr7, COALESCE(randomValue7, 0) as randomValue7, COALESCE(randomAttr8, 0) as randomAttr8, COALESCE(randomValue8, 0) as randomValue8, COALESCE(randomAttr9, 0) as randomAttr9, COALESCE(randomValue9, 0) as randomValue9, COALESCE(randomAttr10, 0) as randomAttr10, COALESCE(randomValue10, 0) as randomValue10

					-- user_item (보조무기)

					, i2.id as 'sub_id', i2.name_id as 'sub_name_id'

					-- 신성력

					, COALESCE(c.charge_point, 0) as 'charge_point'

			FROM	user_item i1 (nolock)

			LEFT JOIN user_item_option o1(nolock) ON i1.id = o1.id and o1.char_id = _char_id

			LEFT JOIN user_item i2 (nolock) ON i2.char_id= _char_id and i2.main_item_dbid = i1.id and i2.warehouse = 16	-- 합성보조무기

			LEFT JOIN user_item_charge c (nolock) ON i1.id = c.id	-- 신성력

			LEFT JOIN user_item_freeTrade f (nolock) on i1.id = f.id

			LEFT JOIN user_item_attribute a (nolock) on i1.id = a.id

			WHERE	i1.char_id = _char_id

			and		i1.warehouse = 0

			and		((i1.name_id BETWEEN 100000000 AND 115099999)/*무기,방어구*/ OR (i1.name_id BETWEEN 125000000 AND 125399999)/*투구*/);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchmychargeditems;
-- +goose StatementEnd
