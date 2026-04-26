-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchHouseByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchhousebycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted			

	

	SELECT	top (1)	

			h.id, h.addr_id, h.building_nameid, 

			h.owner_id, h.owner_type, h.owner_race, h.state, h.permission, h.comment_state, 

			h.roof, h.outwall, h.frame, h.door, h.garden, h.fence, 

			h.inwall1, h.inwall2, h.inwall3, h.inwall4, h.inwall5, h.inwall6, 

			h.infloor1, h.infloor2, h.infloor3, h.infloor4, h.infloor5, h.infloor6, 

			h.addon1, h.addon2, h.addon3, 

			h.flag1, h.flag2, h.flag3, h.flag4, h.flag5, h.flag6, h.flag7, 

			h.comment, h.chargeCount, h.warningCount, h.lastCharge, 

			h.update_time, h.created_time,

			adr.land_nameid, adr.world_id, adr.center_x, adr.center_y, adr.center_z,

			a.id as 'auction_id',  a.type , a.race, 

			a.goodsID, a.sellerID, a.sellerName, a.buyerID, a.buyerName, 

			a.InitQina, a.qina, a.stepQina, a.state as 'auction_state', a.lastUpdate, a.CreateTime, a.BetCount

	FROM	house_field h (nolock)

	JOIN	

			house_addrinfo adr (nolock) ON h.addr_id = adr.addr_id

	LEFT JOIN 

			user_auction a (nolock) ON h.addr_id = a.goodsID 

	WHERE	h.owner_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchhousebycharid;
-- +goose StatementEnd
