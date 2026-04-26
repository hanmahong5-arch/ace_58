-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchHouseObjectByOwnerID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchhouseobjectbyownerid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted			

			

			SELECT	o.id, o.object_nameid, o.object_type, o.owner_id, o.owner_type, 

					o.state, o.expired_time, o.general_use_count, 

					o.world, o.xlocation, o.ylocation, o.zlocation, o.dir, 

					o.update_time, o.created_time, o.dye_info, o.expire_dye_time,

					e.char_id, e.accumulated_usecount, e.next_resettime_for_owner, e.resource_id, e.account_id, e.cur_owner_usecnt_per_day

			FROM	houseobject o (nolock)

			LEFT JOIN

					houseobject_extdata e (nolock) on o.owner_id = _char_id and o.id = e.obj_id

			WHERE	o.owner_id = _char_id

			ORDER BY o.object_type, o.id DESC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchhouseobjectbyownerid;
-- +goose StatementEnd
