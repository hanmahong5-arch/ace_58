-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFamiliarDA_Insert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfamiliarda_insert(_char_id INTEGER, _base_name_id INTEGER, _cur_name_id INTEGER, _name TEXT, _evolve_cnt INTEGER, _growth_point INTEGER, _create_time BIGINT, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_familiar (char_id ,base_name_id, cur_name_id, name, evolve_cnt, create_time, update_time, safety_flag, growth_point, slot1, slot2, slot3, slot4, slot5, slot6, looting_state, deleted) 

VALUES (_char_id, _base_name_id, _cur_name_id, _name, _evolve_cnt, _create_time, _update_time, 0, _growth_point, 0, 0, 0, 0, 0, 0, 0, 0);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfamiliarda_insert;
-- +goose StatementEnd
