-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchHouseObjectExtDataByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchhouseobjectextdatabycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	obj_id, char_id, accumulated_usecount, next_resettime_for_owner, resource_id, account_id, cur_owner_usecnt_per_day

	FROM	houseobject_extdata (nolock)

	WHERE	char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchhouseobjectextdatabycharid;
-- +goose StatementEnd
