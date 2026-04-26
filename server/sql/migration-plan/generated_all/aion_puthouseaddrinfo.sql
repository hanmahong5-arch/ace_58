-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutHouseAddrInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthouseaddrinfo(_addr_id INTEGER, _land_name_id INTEGER, _world_id INTEGER, _center_x DOUBLE PRECISION, _center_y DOUBLE PRECISION, _center_z DOUBLE PRECISION)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT addr_id FROM house_addrinfo(UPDLOCK) WHERE addr_id = _addr_id)

	BEGIN

		UPDATE house_addrinfo

		SET land_nameid = _land_name_id, world_id = _world_id, center_x = _center_x, center_y = _center_y, center_z = _center_z

		WHERE addr_id = _addr_id

	END

	ELSE

	BEGIN

		INSERT house_addrinfo (addr_id, land_nameid, world_id, center_x, center_y, center_z)

		VALUES (_addr_id, _land_name_id, _world_id, _center_x, _center_y, _center_z)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseaddrinfo;
-- +goose StatementEnd
