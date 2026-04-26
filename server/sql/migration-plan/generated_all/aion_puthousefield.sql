-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutHouseField.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthousefield(_id INTEGER, _addr_id INTEGER, _building_nameid INTEGER, _owner_id INTEGER, _owner_type INTEGER, _owner_race INTEGER, _state INTEGER, _permission INTEGER, _comment_state INTEGER, _roof INTEGER, _outwall INTEGER, _frame INTEGER, _door INTEGER, _garden INTEGER, _fence INTEGER, _inwall1 INTEGER, _inwall2 INTEGER, _inwall3 INTEGER, _inwall4 INTEGER, _inwall5 INTEGER, _inwall6 INTEGER, _infloor1 INTEGER, _infloor2 INTEGER, _infloor3 INTEGER, _infloor4 INTEGER, _infloor5 INTEGER, _infloor6 INTEGER, _addon1 INTEGER, _addon2 INTEGER, _addon3 INTEGER, _flag1 BOOLEAN, _flag2 BOOLEAN, _flag3 BOOLEAN, _flag4 BOOLEAN, _flag5 BOOLEAN, _flag6 BOOLEAN, _flag7 BOOLEAN, _comment TEXT, _owner_name TEXT, _legion_id INTEGER, _emblem_version INTEGER, _emblem_bgcolor INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


-- useless param: emblem_version, emblem_bgcolor, legionId

	INSERT house_field (id, addr_id, building_nameid, owner_id, owner_type, owner_race, state, permission, comment_state, roof, outwall, frame, door, garden, fence, inwall1, inwall2, inwall3, inwall4, inwall5, inwall6, infloor1, infloor2, infloor3, infloor4, infloor5, infloor6, addon1, addon2, addon3, flag1, flag2, flag3, flag4, flag5, flag6, flag7, comment, owner_name, update_time, created_time)

	VALUES (_id, _addr_id, _building_nameid, _owner_id, _owner_type, _owner_race, _state, _permission, _comment_state, _roof, _outwall, _frame, _door, _garden, _fence, _inwall1, _inwall2, _inwall3, _inwall4, _inwall5, _inwall6, _infloor1, _infloor2, _infloor3, _infloor4, _infloor5, _infloor6, _addon1, _addon2, _addon3, _flag1, _flag2, _flag3, _flag4, _flag5, _flag6, _flag7, _comment, _owner_name, NOW(), NOW())

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthousefield;
-- +goose StatementEnd
