-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchAuctionHistoryByBuyerID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchauctionhistorybybuyerid(_type INTEGER, _buyer_i_d INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


			set transaction isolation level read uncommitted



			SELECT	id, type, race, goodsID, sellerID, sellerName, buyerID, buyerName, 

					InitQina, qina, stepQina, state, lastUpdate, CreateTime, BetCount

			FROM	user_auction (nolock)

			WHERE	type = _type

			AND		buyerID = _buyer_i_d

			ORDER BY id DESC




		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchauctionhistorybybuyerid;
-- +goose StatementEnd
