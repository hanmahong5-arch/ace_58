-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemRandomOptionall_20180209.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemrandomoptionall_20180209(_item_id BIGINT, _random_option INTEGER, _limit_enchant INTEGER, _option_count INTEGER, _random_attr1 INTEGER, _random_value1 INTEGER, _random_attr2 INTEGER, _random_value2 INTEGER, _random_attr3 INTEGER, _random_value3 INTEGER, _random_attr4 INTEGER, _random_value4 INTEGER, _random_attr5 INTEGER, _random_value5 INTEGER, _random_attr6 INTEGER, _random_value6 INTEGER, _random_attr7 INTEGER, _random_value7 INTEGER, _random_attr8 INTEGER, _random_value8 INTEGER, _random_attr9 INTEGER, _random_value9 INTEGER, _random_attr10 INTEGER, _random_value10 INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item_option SET random_option = _random_option, limit_enchant_count = _limit_enchant, option_count = _option_count,

	randomAttr1 = _random_attr1,

	randomValue1 = _random_value1,

	randomAttr2 = _random_attr2,

	randomValue2 = _random_value2,

	randomAttr3 = _random_attr3,

	randomValue3 = _random_value3,

	randomAttr4 = _random_attr4,

	randomValue4 = _random_value4,

	randomAttr5 = _random_attr5,

	randomValue5 = _random_value5,

	randomAttr6 = _random_attr6,

	randomValue6 = _random_value6,

	randomAttr7 = _random_attr7,

	randomValue7 = _random_value7,

	randomAttr8 = _random_attr8,

	randomValue8 = _random_value8,

	randomAttr9 = _random_attr9,

	randomValue9 = _random_value9,

	randomAttr10 = _random_attr10,

	randomValue10 = _random_value10	

	WHERE id = _item_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemrandomoptionall_20180209;
-- +goose StatementEnd
