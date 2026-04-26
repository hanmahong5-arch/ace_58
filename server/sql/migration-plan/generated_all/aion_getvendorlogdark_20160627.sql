-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorLogDark_20160627.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendorlogdark_20160627(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT item_name_id, sold_price, sold_amount, remain_amount, sold_date,

	soul_bound,enchant_count,skin_name_id,

	COALESCE(stat_enchant_name0, 0), COALESCE(stat_enchant_name1,0),

	COALESCE(stat_enchant_name2, 0), COALESCE(stat_enchant_name3, 0),

	COALESCE(stat_enchant_name4, 0), COALESCE(stat_enchant_name5, 0),

	option_count, dye_info, proc_tool_nameid, producer, COALESCE(limit_enchant_count, 0),

	COALESCE(authorize_count, 0), COALESCE(vanish_point,0),	

	COALESCE(enchant_prob_addition, 0),

	COALESCE(option_prob_addition, 0),

	after_fee, after_tax

	FROM vendor_log_dark

	WHERE (char_id = _char_id)


END



/*

	*** GetVendorCollectibleGold 천족

*/



SET ANSI_NULLS OFF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendorlogdark_20160627;
-- +goose StatementEnd
