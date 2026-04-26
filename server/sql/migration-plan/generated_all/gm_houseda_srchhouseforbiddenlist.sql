-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchHouseForbiddenList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchhouseforbiddenlist(_race TEXT, _size TEXT, _state TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(2000)		

			

			_sql := 'select t1.*, t2.type, t3.user_id, COALESCE(t3.org_server,0) as org_server,'+

			't4.land_nameid, t4.world_id, t4.center_x, t4.center_y, t4.center_z '+

			'from house_field t1 join user_auctionfilter t2 on t1.addr_id=t2.goodsid '+

			'left outer join user_data t3 on t1.owner_id=t3.char_id '+

			'join house_addrinfo t4 on t1.addr_id=t4.addr_id '+

			'where t2.type=1 and '+_race+' and ' + _size + ' and ' + _state			

			

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchhouseforbiddenlist;
-- +goose StatementEnd
