-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchCurDarkVendorItems.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchcurdarkvendoritems(_warehouse TEXT, _name_id TEXT, _char_nm TEXT, _char_id TEXT, _from_name_id TEXT, _to_name_id TEXT, _view_count TEXT, _top_count TEXT, _world_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(4000), _sql_where_etc nvarchar(2500)



			_sql_where_etc := ' and u.delete_date=''0'' '

			

			IF _name_id != 'null'

			BEGIN

				_sql_where_etc := _sql_where_etc + ' and ('+_name_id+') '

			END

			

			IF _char_nm != 'null'

			BEGIN

				_sql_where_etc := _sql_where_etc + ' and u.user_id = N'''+_char_nm+''' '

			END

			

			IF _char_id != 'null'

			BEGIN

				_sql_where_etc := _sql_where_etc + ' and u.char_id = '''+_char_id+''' '

			END



			IF _from_name_id != 'null'

			BEGIN

				_sql_where_etc := _sql_where_etc + ' and i.name_id between '''+_from_name_id+''' AND '''+_to_name_id+''' '

			END

			

			_sql := 'SELECT top ' + _view_count +

						'		v.user_price, v.sale_price, v.commit_amount, v.remain_amount, v.commit_date ' +

						-- 5.3 4차 경매장 개선

						'		, v.afterUnitFee, v.afterUnitTax ' +

						'		, i.producer, i.tid, i.expired_time, i.buy_amount, i.buy_duration, i.id, i.name_id, i.amount, i.slot, i.warehouse ' +

						'		, o.soul_bound, o.enchant_count, o.skin_name_id, o.stat_enchant_name0, o.stat_enchant_name1, o.stat_enchant_name2, o.stat_enchant_name3, o.stat_enchant_name4, o.stat_enchant_name5, o.dye_info, o.proc_tool_nameid ' +

						'		, obtain_skin_type, expire_skin_time, expire_dye_time, COALESCE(random_option,0) AS random_option, COALESCE(limit_enchant_count,0) AS limit_enchant_count, COALESCE(reidentify_count,0) AS reidentify_count ' +

						'		, u.class, u.delete_date, u.org_server, u.char_id, u.user_id, u.account_id, u.account_name, u.race, u.lev ' +

						'		, CASE ' +

						'			WHEN u.last_login_time = u.last_logout_time and u.last_login_time != ''1970-01-01 00:00:00.000'' and u.last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' +

						'			WHEN u.last_login_time != u.last_logout_time or u.last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' +

						'			WHEN u.last_login_time = u.last_logout_time and u.last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' +

						'			END as logonoff '+

						'		, COALESCE(freetradestate, 0) as freetradestate ' +

						'		, COALESCE(authorize_count, 0) as authorize_count, COALESCE(vanish_point, 0) as vanish_point ' +

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

						' FROM	vendor_item_dark v (nolock) ' +

						' JOIN	user_item i (nolock) on i.id = v.user_item_id ' +

						' JOIN	user_data u (nolock) on u.char_id=i.char_id ' +

						' LEFT JOIN user_item_option o (nolock) on i.id = o.id and i.char_id = o.char_id ' +

						' LEFT JOIN user_item_freeTrade f (nolock) on i.id = f.id ' +

						' LEFT JOIN user_item_attribute a (nolock) on i.id = a.id ' +

						' WHERE	i.warehouse='''+_warehouse+''' and u.org_server = '''+_world_id+'''' +

						' AND	i.id not in (SELECT top ' + _top_count + ' i.id ' +

						'	FROM	vendor_item_dark v (nolock), user_item i (nolock), user_data u (nolock) ' +

						'	WHERE	i.warehouse='''+_warehouse+''' and v.user_item_id=i.id and u.org_server = '''+_world_id+''' and u.char_id=i.char_id ' + _sql_where_etc +

						'	ORDER BY i.id asc)'

			

			_sql := _sql + _sql_where_etc

			

			_sql := _sql +

						' ORDER BY i.id asc'

			

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchcurdarkvendoritems;
-- +goose StatementEnd
