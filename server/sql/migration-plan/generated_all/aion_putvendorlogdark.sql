-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutVendorLogDark.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putvendorlogdark(_char_id INTEGER, _item_name_id INTEGER, _sold_price BIGINT, _sold_amount BIGINT, _remain_amount BIGINT, _sold_date INTEGER, _soul_bound INTEGER, _enchant_count INTEGER, _skin_name_id INTEGER, _stat_enchant0 INTEGER, _stat_enchant1 INTEGER, _stat_enchant2 INTEGER, _stat_enchant3 INTEGER, _stat_enchant4 INTEGER, _stat_enchant5 INTEGER, _option_count INTEGER, _dye_info INTEGER, _proc_tool_name_id INTEGER, _random_option INTEGER, _limit_enchant_count INTEGER, _reidentity_count INTEGER, _authorize_count INTEGER, _vanish_point INTEGER, _enchant_prob_addition INTEGER, _option_prob_addition INTEGER, _producer TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT INTO vendor_log_Dark

	(char_id, item_name_id, sold_price, sold_amount, remain_amount, sold_date,

	soul_bound,enchant_count,skin_name_id,

	stat_enchant_name0, stat_enchant_name1, 

	stat_enchant_name2, stat_enchant_name3, 

	stat_enchant_name4, stat_enchant_name5,

	option_count, dye_info, proc_tool_nameid,

	random_option, limit_enchant_count, reidentity_count, authorize_count, vanish_point, 	

	enchant_prob_addition, option_prob_addition,

	producer)

VALUES (_char_id, _item_name_id, _sold_price, _sold_amount, _remain_amount, _sold_date,

	_soul_bound, _enchant_count, _skin_name_id,

	_stat_enchant0, _stat_enchant1,

	_stat_enchant2, _stat_enchant3,

	_stat_enchant4, _stat_enchant5,

	_option_count, _dye_info, _proc_tool_name_id,

	_random_option, _limit_enchant_count, _reidentity_count, _authorize_count, _vanish_point, 

	_enchant_prob_addition, _option_prob_addition,

	_producer );
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putvendorlogdark;
-- +goose StatementEnd
