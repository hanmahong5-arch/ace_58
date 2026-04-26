-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPetNew.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetnew(_id BIGINT, _char_id INTEGER, _slot_id INTEGER, _expire_time INTEGER, _function_data1 BIGINT, _function_data1_ex1 BIGINT, _function_data1_ex2 BIGINT, _function_data1_ex3 BIGINT, _function_data2 BIGINT, _function_data2_ex1 BIGINT, _function_data2_ex2 BIGINT, _function_data2_ex3 BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




declare _change_info_time bigint

_change_info_time := GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)



UPDATE user_pet SET slot_id = _slot_id , expired_time = _expire_time,function_data1 = _function_data1, function_data1_ex1 = _function_data1_ex1, function_data1_ex2 = _function_data1_ex2, function_data1_ex3 = _function_data1_ex3, function_data2 = _function_data2, function_data2_ex1 = _function_data2_ex1, function_data2_ex2 = _function_data2_ex2, function_data2_ex3 = _function_data2_ex3, change_info_time = _change_info_time WHERE name_id = _id and char_id = _char_id

	--WHERE id = _id and char_id = _char_id


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetnew;
-- +goose StatementEnd
