-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchItemByCond.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchitembycond(_world__id TEXT, _cond TEXT, _warehouse TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(4000)

			

			if (_warehouse = '3')

			begin				

				-- 레기온 창고

				_sql := 'SELECT	T1.id, T1.char_id, T1.name_id, T1.amount, T1.slot, T1.warehouse, T1.producer, T1.tid, T1.expired_time, T1.buy_amount, T1.buy_duration ' +

							'		, T3.user_id, T3.char_id as account_name, T3.class, T3.account_id ' +

							'		, o.soul_bound, o.enchant_count, o.skin_name_id, o.stat_enchant_name0, o.stat_enchant_name1, o.stat_enchant_name2, o.stat_enchant_name3, o.stat_enchant_name4, o.stat_enchant_name5, o.dye_info, o.proc_tool_nameid, o.obtain_skin_type, o.expire_skin_time, o.expire_dye_time, COALESCE(o.random_option,0) AS random_option ' +

							'		, o.limit_enchant_count, o.reidentify_count ' +

							'		, COALESCE(f.freetradestate, 0) as freetradestate ' +

							'		, COALESCE(o.authorize_count, 0) as authorize_count, COALESCE(o.vanish_point, 0) as vanish_point ' +

							-- 4.5 17차 깃털

							'		, COALESCE(attribute1, 0) as attribute1, COALESCE(attribute1value, 0) as attribute1value, COALESCE(attribute2, 0) as attribute2, COALESCE(attribute2value, 0) as attribute2value, COALESCE(attribute3, 0) as attribute3, COALESCE(attribute3value, 0) as attribute3value, COALESCE(attribute4, 0) as attribute4, COALESCE(attribute4value, 0) as attribute4value, COALESCE(attribute5, 0) as attribute5, COALESCE(attribute5value, 0) as attribute5value, COALESCE(attribute6, 0) as attribute6, COALESCE(attribute6value, 0) as attribute6value ' +

							-- [4.71] 모조신석

							'		, COALESCE(proc_break_count, 0) as proc_break_count, COALESCE(proc_break_flag, 0) as proc_break_flag ' +

							-- [4.75] 돌파스킬

							'		, COALESCE(exceedState, 0) as exceedState, COALESCE(exceedSkillId1, 0) as exceedSkillId1, COALESCE(exceedSkillId2, 0) as exceedSkillId2, COALESCE(exceedSkillId3, 0) as exceedSkillId3 ' +

							-- [4.9] 최강무기 스킬

							'		, COALESCE(baseSkillId, 0) as baseSkillId ' +

							-- [5.0] 아이템으로 스킬 강화

							'		, COALESCE(enhanceSkillGroup, 0) as enhanceSkillGroup, COALESCE(enhanceSkillLevel, 0) as enhanceSkillLevel ' +

							-- [5.0] 아이템 레벨 다운

							'		, COALESCE(equipLevelDown, 0) as equipLevelDown ' +

							'		, COALESCE(wardrobeSlotId, 0) as wardrobeSlotId ' +

							-- [6.2]아이템 랜덤 옵션 (새로운 것)

							'		, COALESCE(randomAttr1, 0) as randomAttr1, COALESCE(randomValue1, 0) as randomValue1 ' +

							'		, COALESCE(randomAttr2, 0) as randomAttr2, COALESCE(randomValue2, 0) as randomValue2 ' +

							'		, COALESCE(randomAttr3, 0) as randomAttr3, COALESCE(randomValue3, 0) as randomValue3 ' +

							'		, COALESCE(randomAttr4, 0) as randomAttr4, COALESCE(randomValue4, 0) as randomValue4 ' +

							'		, COALESCE(randomAttr5, 0) as randomAttr5, COALESCE(randomValue5, 0) as randomValue5 ' +

							'		, COALESCE(randomAttr6, 0) as randomAttr6, COALESCE(randomValue6, 0) as randomValue6 ' +

							'		, COALESCE(randomAttr7, 0) as randomAttr7, COALESCE(randomValue7, 0) as randomValue7 ' +

							'		, COALESCE(randomAttr8, 0) as randomAttr8, COALESCE(randomValue8, 0) as randomValue8 ' +

							'		, COALESCE(randomAttr9, 0) as randomAttr9, COALESCE(randomValue9, 0) as randomValue9 ' +

							'		, COALESCE(randomAttr10, 0) as randomAttr10, COALESCE(randomValue10, 0) as randomValue10 ' +

							' FROM	user_item T1 (nolock) ' +

							' JOIN	guild g (nolock) on g.id = T1.char_id ' +

							' JOIN	user_data T3 (nolock) on g.master_id = T3.char_id ' +

							' LEFT JOIN user_item_option o (nolock) on T1.id = o.id ' +

							' LEFT JOIN user_item_freeTrade f (nolock) on T1.id = f.id ' +

							' LEFT JOIN user_item_attribute a (nolock) on T1.id = a.id ' +

							' WHERE	T1.warehouse = 3 and (' + _cond + ')'

			end

			else if (_warehouse = '2')

			begin

				-- 계정창고

				_sql := 'SELECT	T1.id, T2.char_id/*계정창고템주의*/, T1.name_id, T1.amount, T1.slot, T1.warehouse, T1.producer, T1.tid, T1.expired_time, T1.buy_amount, T1.buy_duration ' +

							'		, T2.char_id, T2.user_id, T2.account_name, T2.account_id, T2.org_server ' +

							'		, o.soul_bound, o.enchant_count, o.skin_name_id, o.stat_enchant_name0, o.stat_enchant_name1, o.stat_enchant_name2, o.stat_enchant_name3, o.stat_enchant_name4, o.stat_enchant_name5, o.dye_info, o.proc_tool_nameid, o.obtain_skin_type, o.expire_skin_time, o.expire_dye_time, COALESCE(o.random_option,0) AS random_option ' +

							'		, o.limit_enchant_count, o.reidentify_count ' +

							'		, COALESCE(f.freetradestate, 0) as freetradestate ' +

							'		, COALESCE(o.authorize_count, 0) as authorize_count, COALESCE(o.vanish_point, 0) as vanish_point ' +

							-- 4.5 17차 깃털

							'		, COALESCE(attribute1, 0) as attribute1, COALESCE(attribute1value, 0) as attribute1value, COALESCE(attribute2, 0) as attribute2, COALESCE(attribute2value, 0) as attribute2value, COALESCE(attribute3, 0) as attribute3, COALESCE(attribute3value, 0) as attribute3value, COALESCE(attribute4, 0) as attribute4, COALESCE(attribute4value, 0) as attribute4value, COALESCE(attribute5, 0) as attribute5, COALESCE(attribute5value, 0) as attribute5value, COALESCE(attribute6, 0) as attribute6, COALESCE(attribute6value, 0) as attribute6value ' +

							-- [4.71] 모조신석

							'		, COALESCE(proc_break_count, 0) as proc_break_count, COALESCE(proc_break_flag, 0) as proc_break_flag ' +

							-- [4.75] 돌파스킬

							'		, COALESCE(exceedState, 0) as exceedState, COALESCE(exceedSkillId1, 0) as exceedSkillId1, COALESCE(exceedSkillId2, 0) as exceedSkillId2, COALESCE(exceedSkillId3, 0) as exceedSkillId3 ' +

							-- [4.9] 최강무기 스킬

							'		, COALESCE(baseSkillId, 0) as baseSkillId ' +

							-- [5.0] 아이템으로 스킬 강화

							'		, COALESCE(enhanceSkillGroup, 0) as enhanceSkillGroup, COALESCE(enhanceSkillLevel, 0) as enhanceSkillLevel ' +

							-- [5.0] 아이템 레벨 다운

							'		, COALESCE(equipLevelDown, 0) as equipLevelDown ' +

							'		, COALESCE(wardrobeSlotId, 0) as wardrobeSlotId ' +

							-- [6.2]아이템 랜덤 옵션 (새로운 것)

							'		, COALESCE(randomAttr1, 0) as randomAttr1, COALESCE(randomValue1, 0) as randomValue1 ' +

							'		, COALESCE(randomAttr2, 0) as randomAttr2, COALESCE(randomValue2, 0) as randomValue2 ' +

							'		, COALESCE(randomAttr3, 0) as randomAttr3, COALESCE(randomValue3, 0) as randomValue3 ' +

							'		, COALESCE(randomAttr4, 0) as randomAttr4, COALESCE(randomValue4, 0) as randomValue4 ' +

							'		, COALESCE(randomAttr5, 0) as randomAttr5, COALESCE(randomValue5, 0) as randomValue5 ' +

							'		, COALESCE(randomAttr6, 0) as randomAttr6, COALESCE(randomValue6, 0) as randomValue6 ' +

							'		, COALESCE(randomAttr7, 0) as randomAttr7, COALESCE(randomValue7, 0) as randomValue7 ' +

							'		, COALESCE(randomAttr8, 0) as randomAttr8, COALESCE(randomValue8, 0) as randomValue8 ' +

							'		, COALESCE(randomAttr9, 0) as randomAttr9, COALESCE(randomValue9, 0) as randomValue9 ' +

							'		, COALESCE(randomAttr10, 0) as randomAttr10, COALESCE(randomValue10, 0) as randomValue10 ' +

							' FROM	user_item T1 (nolock) ' +

							' JOIN	user_data T2 (nolock) on T2.account_id = T1.char_id and T2.delete_complete_date = 0 ' +

							' LEFT JOIN user_item_option o (nolock) on T1.id = o.id and T1.char_id = o.char_id ' +

							' LEFT JOIN user_item_freeTrade f (nolock) on T1.id = f.id ' +

							' LEFT JOIN user_item_attribute a (nolock) on T1.id = a.id ' +

							' WHERE	T2.org_server='''+_world__id+''' and (' + _cond + ') ' +

							' AND	T1.warehouse IN (2,6,56,7,57) '

			end

			else

			begin

				-- 기타창고

				_sql := 'SELECT	T1.id, T1.char_id, T1.name_id, T1.amount, T1.slot, T1.warehouse, T1.producer, T1.tid, T1.expired_time, T1.buy_amount, T1.buy_duration ' +

							'		, T2.char_id, T2.user_id, T2.account_name, T2.account_id, T2.org_server ' +

							'		, o.soul_bound, o.enchant_count, o.skin_name_id, o.stat_enchant_name0, o.stat_enchant_name1, o.stat_enchant_name2, o.stat_enchant_name3, o.stat_enchant_name4, o.stat_enchant_name5, o.dye_info, o.proc_tool_nameid, o.obtain_skin_type, o.expire_skin_time, o.expire_dye_time, COALESCE(o.random_option,0) AS random_option ' +

							'		, o.limit_enchant_count, o.reidentify_count ' +

							'		, COALESCE(f.freetradestate, 0) as freetradestate ' +

							'		, COALESCE(o.authorize_count, 0) as authorize_count, COALESCE(o.vanish_point, 0) as vanish_point ' +

							-- 4.5 17차 깃털

							'		, COALESCE(attribute1, 0) as attribute1, COALESCE(attribute1value, 0) as attribute1value, COALESCE(attribute2, 0) as attribute2, COALESCE(attribute2value, 0) as attribute2value, COALESCE(attribute3, 0) as attribute3, COALESCE(attribute3value, 0) as attribute3value, COALESCE(attribute4, 0) as attribute4, COALESCE(attribute4value, 0) as attribute4value, COALESCE(attribute5, 0) as attribute5, COALESCE(attribute5value, 0) as attribute5value, COALESCE(attribute6, 0) as attribute6, COALESCE(attribute6value, 0) as attribute6value ' +

							-- [4.71] 모조신석

							'		, COALESCE(proc_break_count, 0) as proc_break_count, COALESCE(proc_break_flag, 0) as proc_break_flag ' +

							-- [4.75] 돌파스킬

							'		, COALESCE(exceedState, 0) as exceedState, COALESCE(exceedSkillId1, 0) as exceedSkillId1, COALESCE(exceedSkillId2, 0) as exceedSkillId2, COALESCE(exceedSkillId3, 0) as exceedSkillId3 ' +

							-- [4.9] 최강무기 스킬

							'		, COALESCE(baseSkillId, 0) as baseSkillId ' +

							-- [5.0] 아이템으로 스킬 강화

							'		, COALESCE(enhanceSkillGroup, 0) as enhanceSkillGroup, COALESCE(enhanceSkillLevel, 0) as enhanceSkillLevel ' +

							-- [5.0] 아이템 레벨 다운

							'		, COALESCE(equipLevelDown, 0) as equipLevelDown ' +

							'		, COALESCE(wardrobeSlotId, 0) as wardrobeSlotId ' +

							-- [6.2]아이템 랜덤 옵션 (새로운 것)

							'		, COALESCE(randomAttr1, 0) as randomAttr1, COALESCE(randomValue1, 0) as randomValue1 ' +

							'		, COALESCE(randomAttr2, 0) as randomAttr2, COALESCE(randomValue2, 0) as randomValue2 ' +

							'		, COALESCE(randomAttr3, 0) as randomAttr3, COALESCE(randomValue3, 0) as randomValue3 ' +

							'		, COALESCE(randomAttr4, 0) as randomAttr4, COALESCE(randomValue4, 0) as randomValue4 ' +

							'		, COALESCE(randomAttr5, 0) as randomAttr5, COALESCE(randomValue5, 0) as randomValue5 ' +

							'		, COALESCE(randomAttr6, 0) as randomAttr6, COALESCE(randomValue6, 0) as randomValue6 ' +

							'		, COALESCE(randomAttr7, 0) as randomAttr7, COALESCE(randomValue7, 0) as randomValue7 ' +

							'		, COALESCE(randomAttr8, 0) as randomAttr8, COALESCE(randomValue8, 0) as randomValue8 ' +

							'		, COALESCE(randomAttr9, 0) as randomAttr9, COALESCE(randomValue9, 0) as randomValue9 ' +

							'		, COALESCE(randomAttr10, 0) as randomAttr10, COALESCE(randomValue10, 0) as randomValue10 ' +

							' FROM	user_item T1 (nolock) ' +

							' JOIN	user_data T2 (nolock) on T1.char_id = T2.char_id ' +

							' LEFT JOIN user_item_option o (nolock) on T1.id = o.id ' +

							' LEFT JOIN user_item_freeTrade f (nolock) on T1.id = f.id ' +

							' LEFT JOIN user_item_attribute a (nolock) on T1.id = a.id ' +

							' WHERE	T2.org_server='''+_world__id+''' and (' + _cond + ') '



				if (_warehouse = '0')		-- 인벤

					_sql := _sql + 

							' AND (T1.warehouse='+_warehouse+' or T1.warehouse=50) and T1.export_id = 0'

				else if (_warehouse = '16')	-- 합성무기

					_sql := _sql + 

							' AND (T1.warehouse='+_warehouse+' or T1.warehouse=17)'

				else if (_warehouse = '30')	-- 펫창고

					_sql := _sql + 

							' AND (T1.warehouse between '+_warehouse+' and 49)'

				else						-- 기타

					_sql := _sql + 

							' AND T1.warehouse='+_warehouse

			end

			

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchitembycond;
-- +goose StatementEnd
