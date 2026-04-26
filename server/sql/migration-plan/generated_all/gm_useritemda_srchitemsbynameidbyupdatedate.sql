-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchItemsByNameIDByUpdateDate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchitemsbynameidbyupdatedate(_char_id INTEGER, _name_id INTEGER, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set	transaction isolation level read uncommitted

	

	SELECT i1.id, i1.char_id, i1.name_id, i1.slot_id, i1.amount, i1.slot, i1.warehouse, convert(nvarchar,i1.create_date,21 ) AS create_date, convert(nvarchar,i1.update_date,21 ) AS update_date, i1.producer, i1.tid, i1.expired_time, i1.buy_amount, i1.buy_duration, i1.main_item_dbid, i1.dynamic_property, i1.import_id, i1.export_id, i1.server_of_origin,

			-- user_item_option

			o1.soul_bound, o1.enchant_count, o1.skin_name_id, o1.stat_enchant_name0, o1.stat_enchant_name1, o1.stat_enchant_name2, o1.stat_enchant_name3, o1.stat_enchant_name4, o1.stat_enchant_name5, o1.option_count, o1.dye_info, o1.proc_tool_nameid, o1.obtain_skin_type, o1.expire_skin_time, o1.expire_dye_time, COALESCE(o1.random_option,0) AS random_option

	from	user_item i1 (nolock)

	left join	user_item_option o1 (nolock) on i1.id = o1.id and i1.char_id = o1.char_id

	where	i1.char_id = _char_id and warehouse = _warehouse

	and		(o1.skin_name_id = _name_id or ((COALESCE(o1.skin_name_id, 0) = 0 and i1.name_id = _name_id)))

	order by i1.update_date desc

	


END /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchitemsbynameidbyupdatedate;
-- +goose StatementEnd
