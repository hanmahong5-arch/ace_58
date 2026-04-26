-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFamiliarDA_Update.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfamiliarda_update(_familiar_id BIGINT, _char_id INTEGER, _base_name_id INTEGER, _cur_name_id INTEGER, _name TEXT, _evolve_cnt INTEGER, _growth_point INTEGER, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_familiar 

SET base_name_id = _base_name_id,

	cur_name_id = _cur_name_id,

	name = _name,

	evolve_cnt = _evolve_cnt,

	update_time = _update_time,

	growth_point = _growth_point 

WHERE id = _familiar_id and char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfamiliarda_update;
-- +goose StatementEnd
