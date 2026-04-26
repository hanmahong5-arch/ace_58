-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorItemListCharLight_20160122.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendoritemlistcharlight_20160122(_user_id INTEGER, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SET ROWCOUNT 50	

SELECT vendor_item_light.id, user_item.id, user_item.name_id, vendor_item_light.user_price, 

	vendor_item_light.sale_price, vendor_item_light.commit_amount, 

	vendor_item_light.remain_amount, vendor_item_light.commit_date,

	vendor_item_light.can_buy_partial,

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

	COALESCE(user_item_option.reidentify_count, 0),

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

	COALESCE(user_item_option.equipLevelDown, 0)

FROM	vendor_item_light(NOLOCK) INNER JOIN	user_item(NOLOCK) ON vendor_item_light.user_item_id = user_item.id 

left join user_item_option on user_item.id = user_item_option.id

WHERE (user_item.warehouse = _warehouse) AND (user_item.char_id = _user_id)

SET ROWCOUNT 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendoritemlistcharlight_20160122;
-- +goose StatementEnd
