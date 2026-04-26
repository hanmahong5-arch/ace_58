-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPetWithNameNew.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetwithnamenew(_name TEXT, _id BIGINT, _char_id INTEGER, _slot_id INTEGER, _function_data1 BIGINT, _function_data1_ex1 BIGINT, _function_data1_ex2 BIGINT, _function_data1_ex3 BIGINT, _function_data2 BIGINT, _function_data2_ex1 BIGINT, _function_data2_ex2 BIGINT, _function_data2_ex3 BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	declare _change_info_time bigint

	_change_info_time := GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

	

	UPDATE user_pet SET name = _name, slot_id = _slot_id , function_data1 = _function_data1, function_data1_ex1 = _function_data1_ex1, function_data1_ex2 = _function_data1_ex2, function_data1_ex3 = _function_data1_ex3, function_data2 = _function_data2, function_data2_ex1 = _function_data2_ex1, function_data2_ex2 = _function_data2_ex2, function_data2_ex3 = _function_data2_ex3, change_info_time = _change_info_time WHERE name_id = _id and char_id = _char_id 

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetwithnamenew;
-- +goose StatementEnd
