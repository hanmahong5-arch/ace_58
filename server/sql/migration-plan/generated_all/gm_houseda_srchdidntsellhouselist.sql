-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchDidntSellHouseList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchdidntsellhouselist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


			set transaction isolation level read uncommitted



			SELECT T1.addr_id, T1.owner_race, T1.owner_id, T2.land_nameid

			FROM house_field T1 join house_addrinfo T2 on T1.addr_id=T2.addr_id

			WHERE T1.addr_id IN (SELECT DISTINCT GOODSID FROM user_auction where sellerid=0 and (state=9 or state=10)) -- 경매 유효 상태 판단

			AND T1.addr_id NOT IN (SELECT DISTINCT GOODSID FROM user_auctionfilter) -- 경매 금지 목록 제외

			AND T1.state=2




		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchdidntsellhouselist;
-- +goose StatementEnd
