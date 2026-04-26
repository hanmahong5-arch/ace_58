-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_escrowset.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_escrowset(_id INTEGER, _state INTEGER, _buyer INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    declare _state int

    declare _qina bigint, _item bigint

    SELECT qina, _item = itemid, _state = state INTO _qina from user_escrow where ID = _id

    

    if _state is null

		return -1

		

	if _state <> 1 

		return -2

		

	if _qina = 0 and _item <> 0

	begin 

		declare _warehouse int

		select _warehouse = warehouse from user_item (updlock) where id = _item

		

		if _warehouse is null

			return -3

		

		if _warehouse <> 154

			return -4		

		

		update user_item set warehouse = 0, char_id = 0 where id = _item	-- 기존에 있던 아이템의 warehouse를 변경. 혹시 모를 소유주 문제를 피하기 위해서 소유주도 변경.

	end

	

	update user_escrow set state = _state, buyer = _buyer, completedate = NOW() where ID = _id

	return 0

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_escrowset;
-- +goose StatementEnd
