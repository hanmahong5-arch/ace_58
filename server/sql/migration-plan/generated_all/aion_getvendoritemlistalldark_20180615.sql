-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorItemListAllDark_20180615.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendoritemlistalldark_20180615(_warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT vendor_item_dark.id, user_item.name_id, vendor_item_dark.sale_price, 

		vendor_item_dark.user_price, vendor_item_dark.commit_amount, 

		vendor_item_dark.commit_date,	vendor_item_dark.remain_amount,

		vendor_item_dark.can_buy_partial, vendor_item_dark.afterUnitFee, vendor_item_dark.afterUnitTax,

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

		COALESCE(user_item_option.baseSkillId, 0),

		COALESCE(user_item_option.enhanceSkillGroup,0),

		COALESCE(user_item_option.enhanceSkillLevel,0),

		COALESCE(user_item_option.equipLevelDown, 0),

		COALESCE(user_item_option.randomAttr1, 0), COALESCE(user_item_option.randomValue1, 0),

		COALESCE(user_item_option.randomAttr2, 0), COALESCE(user_item_option.randomValue2, 0),

		COALESCE(user_item_option.randomAttr3, 0), COALESCE(user_item_option.randomValue3, 0),

		COALESCE(user_item_option.randomAttr4, 0), COALESCE(user_item_option.randomValue4, 0),

		COALESCE(user_item_option.randomAttr5, 0), COALESCE(user_item_option.randomValue5, 0),

		COALESCE(user_item_option.randomAttr6, 0), COALESCE(user_item_option.randomValue6, 0),

		COALESCE(user_item_option.randomAttr7, 0), COALESCE(user_item_option.randomValue7, 0),

		COALESCE(user_item_option.randomAttr8, 0), COALESCE(user_item_option.randomValue8, 0),

		COALESCE(user_item_option.randomAttr9, 0), COALESCE(user_item_option.randomValue9, 0),

		COALESCE(user_item_option.randomAttr10, 0), COALESCE(user_item_option.randomValue10, 0),

		COALESCE(COALESCE(user_item_option.skill_skin_name_Id, user_Item_option.skin_name_id), 0)

	FROM	vendor_item_dark INNER JOIN

		user_item ON vendor_item_dark.user_item_id = user_item.id left JOIN 

		user_item_option on user_item.id = user_item_option.id inner join

		user_data ON vendor_item_dark.char_id = user_data.char_id

	WHERE (user_item.warehouse = _warehouse)


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendoritemlistalldark_20180615;
-- +goose StatementEnd
