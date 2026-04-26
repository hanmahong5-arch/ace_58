-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutFamiliar.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putfamiliar(_name TEXT, _master_id INTEGER, _base_name_id INTEGER, _name_id INTEGER, _evolve_cnt INTEGER, _create_time BIGINT, _update_time BIGINT, _safety_flag INTEGER, _growth_point INTEGER, _slot1 INTEGER, _slot2 INTEGER, _slot3 INTEGER, _slot4 INTEGER, _slot5 INTEGER, _slot6 INTEGER, _looting_state INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




INSERT user_familiar (char_id ,base_name_id, cur_name_id, name, evolve_cnt, create_time, update_time, safety_flag, growth_point, slot1, slot2, slot3, slot4, slot5, slot6, looting_state, deleted) 

VALUES (_master_id, _base_name_id, _name_id, _name, _evolve_cnt, _create_time, _update_time, _safety_flag, _growth_point, _slot1, _slot2, _slot3, _slot4, _slot5, _slot6, _looting_state, 0)






IF @_e_r_r_o_r <> 0

	return 0



return @_i_d_e_n_t_i_t_y

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfamiliar;
-- +goose StatementEnd
