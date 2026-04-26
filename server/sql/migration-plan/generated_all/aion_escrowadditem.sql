-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_escrowadditem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_escrowadditem(_charid INTEGER, _itemid BIGINT, _itemamount BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here        

	update user_item set warehouse = 154 where id = _itemid

	insert into user_escrow (seller, qina, itemid, itemamount, buyer, state, registerdate) values (_charid, 0, _itemid, _itemamount, 0, 1, NOW())

	

	IF @_e_r_r_o_r <> 0

		return 0

	return @_identity

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_escrowadditem;
-- +goose StatementEnd
