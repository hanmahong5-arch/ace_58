-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutPetNew2.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putpetnew2(_name TEXT, _visual_data BYTEA, _char_id INTEGER, _name_id INTEGER, _slot_id INTEGER, _function_data1 BIGINT, _function_data1_ex1 BIGINT, _function_data1_ex2 BIGINT, _function_data1_ex3 BIGINT, _function_data2 BIGINT, _function_data2_ex1 BIGINT, _function_data2_ex2 BIGINT, _function_data2_ex3 BIGINT, _visual_data_size INTEGER, _expired_time INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




declare _change_info_time bigint

_change_info_time := GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)



INSERT user_pet (char_id,name_id,slot_id,name,function_data1,function_data1_ex1,function_data1_ex2,function_data1_ex3,function_data2,function_data2_ex1,function_data2_ex2,function_data2_ex3,visual_data_size,visual_data,change_info_time,expired_time) 

VALUES (_char_id,_name_id,_slot_id,_name,_function_data1,_function_data1_ex1,_function_data1_ex2,_function_data1_ex3,_function_data2,_function_data2_ex1,_function_data2_ex2,_function_data2_ex3,_visual_data_size,_visual_data,_change_info_time,_expired_time)


IF @_e_r_r_o_r <> 0

	return



return @_i_d_e_n_t_i_t_y

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpetnew2;
-- +goose StatementEnd
