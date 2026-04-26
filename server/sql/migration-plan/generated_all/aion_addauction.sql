-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_addAuction.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addauction(_type INTEGER, _race INTEGER, _name_i_d INTEGER, _seller_i_d INTEGER, _seller_name TEXT, _qina BIGINT, _stepqina BIGINT, _create_time INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	if EXISTS (SELECT id FROM user_auction WHERE goodsID = _name_i_d and state in (0,1)) OR 

	   EXISTS(select filterid from user_auctionfilter where goodsID = _name_i_d)

		begin		

			return 0;

		end

	else

		begin

			insert into user_auction(type, race, goodsID, sellerID, sellerName, InitQina, qina, stepqina, state, buyerID, buyerName, lastupdate, createtime) values (_type, _race, _name_i_d, _seller_i_d, _seller_name, _qina, _qina, _stepqina, 0, 0, '', 0, _create_time)

			return @_identity

		end	

	

END



/****** Object:  StoredProcedure aion_updateauctionstate    Script Date: 10/17/2012 10:05:03 ******/

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauction;
-- +goose StatementEnd
