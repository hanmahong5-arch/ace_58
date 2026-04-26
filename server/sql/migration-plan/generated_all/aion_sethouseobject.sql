-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseObject.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseobject(_id INTEGER, _object_nameid INTEGER, _object_type INTEGER, _owner_id INTEGER, _owner_type INTEGER, _state INTEGER, _expired_time INTEGER, _general_use_count INTEGER, _world INTEGER, _xlocation DOUBLE PRECISION, _ylocation DOUBLE PRECISION, _zlocation DOUBLE PRECISION, _dir INTEGER, _info_value INTEGER, _expire_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	UPDATE houseobject

	SET object_nameid = _object_nameid, object_type = _object_type, owner_id = _owner_id, owner_type = _owner_type, state = _state, expired_time = _expired_time, general_use_count = _general_use_count, world = _world, xlocation = _xlocation, ylocation = _ylocation, zlocation = _zlocation, dir = _dir, dye_info = _info_value, expire_dye_time = _expire_time, update_time = NOW()

	WHERE id = _id;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseobject;
-- +goose StatementEnd
