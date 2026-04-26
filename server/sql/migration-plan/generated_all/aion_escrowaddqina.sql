-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_escrowaddqina.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_escrowaddqina(_charid INTEGER, _qina BIGINT, _decrease INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    declare _itemid int, _amount bigint

    if _decrease = 1

    begin

		SELECT id, _amount = amount INTO _itemid from user_item(updlock) where char_id=_charid and name_id=182400001 and warehouse=0

		

		if (_amount < _qina)

		begin

			return -2

		end

		

		if _itemid is null or _itemid <= 0 

		begin 

			return -1

		end

		

		update user_item set amount = amount - _qina where id = _itemid

	end

	

	insert into user_escrow (seller, qina, itemid, itemamount, buyer, state, registerdate) values (_charid, _qina, 0, 0, 0, 1, NOW())

	

	IF @_e_r_r_o_r <> 0

		return 0

		

	return @_identity

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_escrowaddqina;
-- +goose StatementEnd
