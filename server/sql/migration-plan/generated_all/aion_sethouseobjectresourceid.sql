-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseObjectResourceId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseobjectresourceid(_obj_id INTEGER, _char_id INTEGER, _res_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT obj_id FROM houseobject_extdata(UPDLOCK) where obj_id = _obj_id)

		BEGIN

			UPDATE houseobject_extdata

			SET	resource_id = _res_id

			WHERE obj_id = _obj_id

		END

	ELSE

		BEGIN

			INSERT houseobject_extdata(obj_id, char_id, resource_id)

			VALUES (_obj_id, _char_id, _res_id)

		END


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseobjectresourceid;
-- +goose StatementEnd
