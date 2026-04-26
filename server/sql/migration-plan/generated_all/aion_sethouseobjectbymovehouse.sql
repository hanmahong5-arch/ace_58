-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseObjectByMoveHouse.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseobjectbymovehouse(_owner_id INTEGER, _owner_type INTEGER, _state INTEGER, _state INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	BEGIN TRAN

	

	UPDATE houseobject

	SET	state = _state,

		world = 0,

		xlocation = 0.0,

		ylocation = 0.0,

		zlocation = 0.0,

		dir = 0

	WHERE owner_id = _owner_id and state = _state

	

	UPDATE houseobject

	SET owner_type = _owner_type,

		update_time = NOW()

	WHERE owner_id = _owner_id and state != 0



	COMMIT TRAN



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseobjectbymovehouse;
-- +goose StatementEnd
