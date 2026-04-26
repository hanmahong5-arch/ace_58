-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchHouseInstanceByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchhouseinstancebycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	id, state, permission, inwall, infloor, update_time, created_time

	FROM	house_instant (nolock)

	WHERE	id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchhouseinstancebycharid;
-- +goose StatementEnd
