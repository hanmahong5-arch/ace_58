-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseField.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethousefield(_id INTEGER, _addr_id INTEGER, _building_nameid INTEGER, _owner_id INTEGER, _owner_type INTEGER, _owner_race INTEGER, _state INTEGER, _permission INTEGER, _comment_state INTEGER, _roof INTEGER, _outwall INTEGER, _frame INTEGER, _door INTEGER, _garden INTEGER, _fence INTEGER, _inwall1 INTEGER, _inwall2 INTEGER, _inwall3 INTEGER, _inwall4 INTEGER, _inwall5 INTEGER, _inwall6 INTEGER, _infloor1 INTEGER, _infloor2 INTEGER, _infloor3 INTEGER, _infloor4 INTEGER, _infloor5 INTEGER, _infloor6 INTEGER, _addon1 INTEGER, _addon2 INTEGER, _addon3 INTEGER, _flag1 BOOLEAN, _flag2 BOOLEAN, _flag3 BOOLEAN, _flag4 BOOLEAN, _flag5 BOOLEAN, _flag6 BOOLEAN, _flag7 BOOLEAN, _comment TEXT, _owner_name TEXT, _legion_id INTEGER, _emblem_version INTEGER, _emblem_bgcolor INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT USER_ID INTO _owner_name from user_data where char_id = _owner_id

	

	UPDATE house_field SET addr_id = _addr_id, building_nameid = _building_nameid, owner_id = _owner_id, owner_type = _owner_type, owner_race = _owner_race, state = _state, permission = _permission, comment_state = _comment_state, 

		roof = _roof, outwall = _outwall, frame = _frame, door = _door, garden = _garden, fence = _fence, inwall1 = _inwall1, inwall2 = _inwall2, inwall3 = _inwall3, inwall4 = _inwall4, inwall5 = _inwall5, inwall6 = _inwall6, infloor1 = _infloor1, infloor2 = _infloor2, infloor3 = _infloor3, infloor4 = _infloor4, infloor5 = _infloor5, infloor6 = _infloor6, addon1 = _addon1, addon2 = _addon2, addon3 = _addon3, 

		flag1 = _flag1, flag2 = _flag2, flag3 = _flag3, flag4 = _flag4, flag5 = _flag5, flag6 = _flag6, flag7 = _flag7,

		comment = _comment, owner_name = _owner_name, update_time = NOW(), legion_id = _legion_id, emblem_version = _emblem_version, emblem_bgcolor = _emblem_bgcolor

	WHERE id = _id;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethousefield;
-- +goose StatementEnd
