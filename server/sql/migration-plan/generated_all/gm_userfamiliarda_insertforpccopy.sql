-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFamiliarDA_InsertForPCCOPY.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfamiliarda_insertforpccopy(_char_id INTEGER, _base_name_id INTEGER, _cur_name_id INTEGER, _name TEXT, _evolve_cnt INTEGER, _create_time BIGINT, _update_time BIGINT, _safety_flag INTEGER, _growth_point INTEGER, _slot1 INTEGER, _slot2 INTEGER, _slot3 INTEGER, _slot4 INTEGER, _slot5 INTEGER, _slot6 INTEGER, _looting_state INTEGER, _deleted INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	INSERT INTO user_familiar (char_id, base_name_id, cur_name_id, name, evolve_cnt, create_time, update_time, safety_flag, growth_point, slot1, slot2, slot3, slot4, slot5, slot6, looting_state, deleted)

	VALUES (_char_id, _base_name_id, _cur_name_id, _name, _evolve_cnt, _create_time, _update_time, _safety_flag, _growth_point, _slot1, _slot2, _slot3, _slot4, _slot5, _slot6, _looting_state, _deleted)

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfamiliarda_insertforpccopy;
-- +goose StatementEnd
