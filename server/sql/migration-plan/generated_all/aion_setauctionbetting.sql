-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_setAuctionBetting.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setauctionbetting(_ownerid INTEGER, _auctionid INTEGER, _qina BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	if exists (select ownerid from user_betting(updlock) where ownerid = _ownerid)

		update user_betting set auctionid = _auctionid, qina = _qina where ownerid = _ownerid

	else 

		insert into user_betting (ownerid, auctionid, qina) values(_ownerid, _auctionid, _qina)



	return _ownerid

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctionbetting;
-- +goose StatementEnd
