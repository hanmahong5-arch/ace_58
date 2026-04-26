-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchAllAttributesOfItemByDBID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchallattributesofitembydbid(_char_id TEXT, _db_id TEXT, _sub_item_warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



			SELECT -- user_item (메인무기)

					i1.id, i1.char_id, i1.name_id, i1.slot_id, i1.amount, i1.slot, i1.warehouse, convert(nvarchar,i1.create_date,21 ) AS create_date, convert(nvarchar,i1.update_date,21 ) AS update_date, i1.producer, i1.tid, i1.expired_time, i1.buy_amount, i1.buy_duration, i1.main_item_dbid, i1.dynamic_property, i1.import_id, i1.export_id, i1.server_of_origin,

					-- user_item_option

					o1.soul_bound, o1.enchant_count, o1.skin_name_id, o1.stat_enchant_name0, o1.stat_enchant_name1, o1.stat_enchant_name2, o1.stat_enchant_name3, o1.stat_enchant_name4, o1.stat_enchant_name5, o1.option_count, o1.dye_info, o1.proc_tool_nameid, o1.obtain_skin_type, o1.expire_skin_time, o1.expire_dye_time, COALESCE(o1.random_option,0) AS random_option,

					COALESCE(o1.limit_enchant_count,0) AS limit_enchant_count, COALESCE(o1.reidentify_count,0) AS reidentify_count,

					-- user_item (보조무기)



					COALESCE(i2.id, 0) as 'sub_id', COALESCE(i2.name_id, 0) as 'sub_name_id', COALESCE(i2.amount, 0) as sub_amount, 

					-- user_item_option

					COALESCE(o2.enchant_count,0) AS sub_enchant_count, COALESCE(o2.skin_name_id,0) AS sub_skin_name_id, 

					COALESCE(o2.stat_enchant_name0,0) AS sub_stat_enchant_name0, COALESCE(o2.stat_enchant_name1,0) AS sub_stat_enchant_name1, COALESCE(o2.stat_enchant_name2,0) AS sub_stat_enchant_name2, COALESCE(o2.stat_enchant_name3,0) AS sub_stat_enchant_name3, COALESCE(o2.stat_enchant_name4,0) AS sub_stat_enchant_name4, COALESCE(o2.stat_enchant_name5,0) AS sub_stat_enchant_name5,

					COALESCE(o2.proc_tool_nameid,0) as sub_proc_tool_nameid, COALESCE(o2.option_count, 0) as sub_option_count, COALESCE(o2.dye_info, 0) as sub_dye_info,

					-- 신성력

					COALESCE(c.charge_point, 0) as 'charge_point',COALESCE(c2.charge_point, 0) as 'sub_charge_point'

			FROM	user_item i1 (nolock)

			LEFT JOIN user_item_option o1(nolock) ON i1.id = o1.id and o1.char_id = _char_id and i1.id = _db_id

			LEFT JOIN user_item i2 (nolock) ON i2.char_id= _char_id and i2.main_item_dbid = i1.id and i2.warehouse = _sub_item_warehouse	-- 합성보조무기

			LEFT JOIN user_item_option o2(nolock) ON i2.id = o2.id and o2.char_id = i2.char_id

			LEFT JOIN user_item_charge c (nolock) ON i1.id = c.id	-- 신성력

			LEFT JOIN user_item_charge c2 (nolock) ON i2.id = c2.id	-- 신성력sub

			WHERE	i1.char_id = _char_id and i1.id = _db_id

			order by i2.update_date desc


 /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchallattributesofitembydbid;
-- +goose StatementEnd
