-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchAllHouseList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchallhouselist(_race TEXT, _size TEXT, _state TEXT, _user_id TEXT, _account_name TEXT, _obj_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(3000)

			

			_sql := 'select t2.user_id, COALESCE(t2.org_server,0) as org_server,' +

			't1.*, '+

			't3.id as auction_id, t3.race, t3.sellerid, t3.sellername, t3.buyerid, t3.buyername, t3.qina, t3.stepqina, t3.createtime, t3.betCount, t3.lastupdate,'+

			't4.land_nameid, t4.world_id, t4.center_x, t4.center_y, t4.center_z '+			

			'from house_field t1(nolock) left outer join user_data t2(nolock) on t1.owner_id=t2.char_id ' +

			'left outer join user_auction t3 on t1.addr_id=t3.goodsid and (t3.state=0 or t3.state=1)'+

			' join house_addrinfo t4 on t1.addr_id=t4.addr_id '+

			'left outer join user_auctionfilter t5 on t1.addr_id=t5.goodsID '+

			'where t5.goodsID is null '

			

			if _race != ''

			begin

				_sql := _sql + 'and ' + _race

			end

			

			if _size != ''

			begin

				_sql := _sql + 'and ' + _size

			end

			

			if _state = '(t1.state=6)'

				_sql := _sql + 'and t1.chargeCount <= 0'

			else 

			begin

				if _state != ''

				begin

					_sql := _sql + 'and ' + _state

				end

			end

			

			if _user_id is not null

			begin

				_sql := _sql + ' and t2.user_id=''' + _user_id + ''' '

			end

			

			if _account_name is not null

			begin

				_sql := _sql + ' and t2.account_name=''' + _account_name + ''' '

			end



			if _obj_id != 0

			begin

				_sql := _sql + ' and t1.addr_id=' + _obj_id

			end
RAISE NOTICE '%', _sql;

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchallhouselist;
-- +goose StatementEnd
