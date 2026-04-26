-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHouseObjectFieldAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseobjectfieldall()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT id, object_nameid, object_type, owner_id, owner_type, state, expired_time, general_use_count, world, xlocation, ylocation, zlocation, dir, COALESCE(dye_info, 0), COALESCE(expire_dye_time, 0)

	FROM houseobject WHERE owner_type > 1 and state != 0

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseobjectfieldall;
-- +goose StatementEnd
