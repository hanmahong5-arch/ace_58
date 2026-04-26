-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddAuctionGrace.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addauctiongrace(_ownerid INTEGER, _goodsid INTEGER, _buildingid INTEGER, _starttime INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    insert into user_grace (owner_id, goods_id, building_id, starttime, state) values (_ownerid, _goodsid, _buildingid, _starttime, 0)

    return @_identity

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauctiongrace;
-- +goose StatementEnd
