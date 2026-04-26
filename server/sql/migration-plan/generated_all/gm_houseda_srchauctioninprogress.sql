-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_HouseDA_SrchAuctionInProgress.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_houseda_srchauctioninprogress(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


			set transaction isolation level read uncommitted



			SELECT	id, type, race, goodsID, sellerID, sellerName, buyerID, buyerName, 

					InitQina, qina, stepQina, state, lastUpdate, CreateTime, BetCount

			FROM	user_auction (nolock)

			where (sellerID = _char_id and state = 0) or (buyerID = _char_id and state = 1)




		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_houseda_srchauctioninprogress;
-- +goose StatementEnd
