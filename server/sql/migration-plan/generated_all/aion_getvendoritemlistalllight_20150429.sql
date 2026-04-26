-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorItemListAllLight_20150429.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendoritemlistalllight_20150429(_warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT vendor_item_light.id, user_item.name_id, vendor_item_light.sale_price, 

	vendor_item_light.user_price, vendor_item_light.commit_amount, 

	vendor_item_light.commit_date,	vendor_item_light.remain_amount,

	vendor_item_light.can_buy_partial,

	user_item.id,  user_data.char_id, user_data.user_id,

	COALESCE(user_item_option.soul_bound,0), COALESCE(user_item_option.enchant_count,0), COALESCE(user_item_option.skin_name_id,0),

	COALESCE(user_item_option.stat_enchant_name0,0),

	COALESCE(user_item_option.stat_enchant_name1,0),

	COALESCE(user_item_option.stat_enchant_name2,0),

	COALESCE(user_item_option.stat_enchant_name3,0),

	COALESCE(user_item_option.stat_enchant_name4,0),

	COALESCE(user_item_option.stat_enchant_name5,0),		

	COALESCE(user_item_option.option_count,0),

	COALESCE(user_item_option.dye_info,0), COALESCE(user_item_option.proc_tool_nameid,0), user_item.producer, 

	COALESCE(user_item_option.expire_dye_time, 0), COALESCE(user_item_option.limit_enchant_count, 0), 

	COALESCE(user_item_option.random_option,0),

	COALESCE(user_item_option.reidentify_count,0),

	COALESCE(user_item_option.authorize_count, 0), 

	COALESCE(user_item_option.vanish_point,0),	

	COALESCE(user_item_option.enchant_prob_addition, 0),

	COALESCE(user_item_option.option_prob_addition, 0),

	COALESCE(user_item_option.keyNameId, 0),

	COALESCE(user_item_option.exceedState, 0),

	COALESCE(user_item_option.exceedSkillId1, 0),

	COALESCE(user_item_option.exceedSkillId2, 0),

	COALESCE(user_item_option.exceedSkillId3, 0),

	COALESCE(user_item_option.baseSkillId, 0)

FROM	vendor_item_light INNER JOIN

	user_item ON vendor_item_light.user_item_id = user_item.id left JOIN 

	user_item_option on user_item.id = user_item_option.id inner join

	user_data ON vendor_item_light.char_id = user_data.char_id

WHERE (user_item.warehouse = _warehouse);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendoritemlistalllight_20150429;
-- +goose StatementEnd
