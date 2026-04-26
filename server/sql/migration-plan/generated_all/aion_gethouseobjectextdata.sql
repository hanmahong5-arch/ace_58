-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHouseObjectExtData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseobjectextdata(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT obj_id, char_id, accumulated_usecount, next_resettime_for_owner, resource_id, account_id, cur_owner_usecnt_per_day

	FROM houseobject_extdata WHERE char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseobjectextdata;
-- +goose StatementEnd
