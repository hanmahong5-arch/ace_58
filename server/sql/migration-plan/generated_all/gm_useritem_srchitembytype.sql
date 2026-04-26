-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItem_SrchItemByType.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritem_srchitembytype(_item_name_id TEXT, _enchant_count_from TEXT, _enchant_count_to TEXT, _amount_from TEXT, _amount_to TEXT, _dbid_from TEXT, _dbid_to TEXT, _multi_user_ids TEXT, _view_count TEXT, _top_count TEXT, _authorize_count_from TEXT, _authorize_count_to TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(4000)

			

			_sql := ' SELECT TOP ' + _view_count +

						-- user_item

						'		i.tid, i.expired_time, i.buy_amount, i.buy_duration, i.id, i.char_id, i.name_id, i.amount, i.slot_id, i.slot, i.warehouse, convert(nvarchar,i.create_date,21 ) create_date, convert(nvarchar,i.update_date,21 ) update_date, i.producer ' +

						-- user_data

						'		, u.char_id, u.user_id, u.account_id, u.account_name ' +

						-- user_item_option

						'		, o.soul_bound, o.enchant_count, o.skin_name_id, o.stat_enchant_name0, o.stat_enchant_name1, o.stat_enchant_name2, o.stat_enchant_name3, o.stat_enchant_name4, o.stat_enchant_name5, o.option_count, o.dye_info, o.proc_tool_nameid, o.obtain_skin_type, o.expire_skin_time, o.expire_dye_time, COALESCE(o.random_option,0) AS random_option ' +

						'		, COALESCE(o.limit_enchant_count,0) AS limit_enchant_count, COALESCE(o.reidentify_count,0) AS reidentify_count ' +

						'		, COALESCE(f.freetradestate, 0) as freetradestate ' +

						'		, COALESCE(o.authorize_count, 0) as authorize_count, COALESCE(o.vanish_point, 0) as vanish_point ' +

						-- 4.5 17차 깃털

						'		, COALESCE(attribute1, 0) as attribute1, COALESCE(attribute1value, 0) as attribute1value, COALESCE(attribute2, 0) as attribute2, COALESCE(attribute2value, 0) as attribute2value, COALESCE(attribute3, 0) as attribute3, COALESCE(attribute3value, 0) as attribute3value, COALESCE(attribute4, 0) as attribute4, COALESCE(attribute4value, 0) as attribute4value, COALESCE(attribute5, 0) as attribute5, COALESCE(attribute5value, 0) as attribute5value, COALESCE(attribute6, 0) as attribute6, COALESCE(attribute6value, 0) as attribute6value ' +

						-- [4.71] 모조신석

						'		, COALESCE(proc_break_count, 0) as proc_break_count, COALESCE(proc_break_flag, 0) as proc_break_flag ' +

						-- [4.75] 돌파스킬

						'		, COALESCE(exceedState, 0) as exceedState, COALESCE(exceedSkillId1, 0) as exceedSkillId1, COALESCE(exceedSkillId2, 0) as exceedSkillId2, COALESCE(exceedSkillId3, 0) as exceedSkillId3 ' +

						-- [4.9] 최강무기 스킬

						'		, COALESCE(baseSkillId, 0) as baseSkillId' +

						-- [5.0] 아이템으로 스킬 강화

						'		, COALESCE(enhanceSkillGroup, 0) as enhanceSkillGroup, COALESCE(enhanceSkillLevel, 0) as enhanceSkillLevel ' +

						-- [5.0] 아이템 레벨 다운

						'		, COALESCE(equipLevelDown, 0) as equipLevelDown' +

						'		, COALESCE(wardrobeSlotId, 0) as wardrobeSlotId' +

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

						' FROM	user_item i (nolock) ' +

						' JOIN	user_data u (nolock) on i.char_id = u.char_id ' +

						' LEFT JOIN user_item_option o (nolock) on i.id = o.id and i.char_id = o.char_id ' +

						' LEFT JOIN user_item_freeTrade f (nolock) on i.id = f.id ' +

						' LEFT JOIN user_item_attribute a (nolock) on i.id = a.id ' +

						' WHERE	u.delete_complete_date = 0 ' +

						' AND	(i.warehouse IN (0, 1, 3, 4, 5) or (i.warehouse between 30 and 49) or (i.warehouse between 60 and 79)) '

			

			IF _multi_user_ids != 'null'

			BEGIN

				_sql := _sql	+ 

						' AND ('+_multi_user_ids+') '

			END

			

			IF _item_name_id != 'null'

			BEGIN

				_sql := _sql + 

						' AND ('+_item_name_id+' ) '

			END 

			

			IF _enchant_count_from != 'null' AND _enchant_count_to != 'null'

			BEGIN

				_sql := _sql + 

						' AND o.enchant_count >= '''+_enchant_count_from+''' and o.enchant_count <= '''+_enchant_count_to+''' '

			END

			

			IF _amount_from != 'null' AND _amount_to != 'null'

			BEGIN

				_sql := _sql + 

						' AND i.amount >= '''+_amount_from+''' and i.amount <= '''+_amount_to+''' '

			END

			

			IF _dbid_from != 'null' AND _dbid_to != 'null'

			BEGIN

				_sql := _sql + 

						' AND i.id >= '''+_dbid_from+''' and i.id <= '''+_dbid_to+''' '

			END

			

			IF _authorize_count_from != 'null' AND _authorize_count_to != 'null'

			BEGIN

				_sql := _sql + 

						' AND o.authorize_count >= '''+_authorize_count_from+''' and o.authorize_count <= '''+_authorize_count_to+''' '

			END

			

				_sql := _sql + 

						' AND i.id not in (' + 

							' SELECT top ' + _top_count + ' i.id ' +

							' FROM	user_item i(nolock), user_data u(nolock) ' +

							' WHERE	delete_complete_date = 0 and i.char_id = u.char_id ' +

							' AND	(i.warehouse in (0, 1, 3, 4, 5) or (i.warehouse between 30 and 49) or (i.warehouse between 60 and 79))' 

			

			IF _multi_user_ids != 'null'

			BEGIN

				_sql := _sql + 

							' AND ('+_multi_user_ids+') '

			END

			

			IF _item_name_id != 'null'

			BEGIN

				_sql := _sql + 

							' AND ('+_item_name_id+' ) '

			END

			

			IF _enchant_count_from != 'null' AND _enchant_count_to != 'null'

			BEGIN

				_sql := _sql + 

							' AND o.enchant_count >= '''+_enchant_count_from+''' and o.enchant_count <= '''+_enchant_count_to+''' '

			END

			

			IF _amount_from != 'null' AND _amount_to != 'null'

			BEGIN

				_sql := _sql + 

							' AND i.amount >= '''+_amount_from+''' and i.amount <= '''+_amount_to+''' '

			END

			

			IF _dbid_from != 'null' AND _dbid_to != 'null'

			BEGIN

				_sql := _sql +

							' AND i.id >= '''+_dbid_from+''' and i.id <= '''+_dbid_to+''' '

			END

						

			IF _authorize_count_from != 'null' AND _authorize_count_to != 'null'

			BEGIN

				_sql := _sql + 

						' AND o.authorize_count >= '''+_authorize_count_from+''' and o.authorize_count <= '''+_authorize_count_to+''' '

			END

			

				_sql := _sql + 

							' order by i.char_id asc' +

						') order by i.char_id asc '



			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritem_srchitembytype;
-- +goose StatementEnd
