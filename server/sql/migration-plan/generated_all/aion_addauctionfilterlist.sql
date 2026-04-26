-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddAuctionFilterList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addauctionfilterlist(_type INTEGER, _goods INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	if EXISTS(select filterid from user_auctionfilter where goodsID = _goods)

		return

	else

		insert into user_auctionfilter (type, goodsID) values(_type, _goods)



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauctionfilterlist;
-- +goose StatementEnd
