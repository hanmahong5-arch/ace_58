-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_house_give.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_house_give(_addr_id INTEGER, _owner_id INTEGER, _owner_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	declare _ret int

    -- Insert statements for procedure here

	if exists (select addr_id from house_field with(updlock) where addr_id = _addr_id and state = 2)	--No Owner상태인 집이 있고

	begin

		if exists (select addr_id from house_field where owner_id = _owner_id) -- 소유한 집은 없어야 하며

		begin

			_ret := 2

		end

		else

		begin

			if exists (select ID from user_auction where buyerID = _owner_id and state =1) -- 현재 상위 입찰인 집도 없어야 한다.

			begin

				_ret := 3

			end

			else

			begin

				if exists (select ID from house_instant where id = _owner_id and state = 5)

				begin

					_ret := 0

					

					exec aion_deleteAuctionBetting _owner_id



					SELECT user_id INTO _owner_name FROM user_data WITH (nolock) WHERE char_id = _owner_id					



					update house_field set owner_id = _owner_id, state = 5, owner_name = _owner_name where addr_id = _addr_id

					

					declare _lastcharge int

									

					select _lastcharge=max(lastcharge) from house_field

					

					exec aion_SetHouseFieldCharge _addr_id, 1, 0, _lastcharge

				end

				else

				begin 

					_ret := 4

				end

			end

		end

	end 		

	else	

		_ret := 1

	

	return _ret

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_house_give;
-- +goose StatementEnd
