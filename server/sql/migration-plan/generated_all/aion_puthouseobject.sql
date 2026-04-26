-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutHouseObject.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthouseobject(_object_nameid INTEGER, _object_type INTEGER, _owner_id INTEGER, _owner_type INTEGER, _state INTEGER, _expired_time INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	INSERT houseobject (object_nameid, object_type, owner_id, owner_type, state, expired_time, update_time, created_time)

	VALUES (_object_nameid, _object_type, _owner_id, _owner_type, _state, _expired_time, NOW(), NOW())






	IF @_e_r_r_o_r <> 0

		RETURN 0;



	RETURN @_i_d_e_n_t_i_t_y

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseobject;
-- +goose StatementEnd
