-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailGetItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailgetitem(_char_id INTEGER, _mail_id INTEGER, _warehouse INTEGER, _flag INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _item_id bigint

declare _money bigint

declare _ap bigint

_item_id := 0

_money := 0

_ap := 0



begin tran

-- get item id and money

SELECT item_id, _money = money, _ap = abyss_point INTO _item_id from user_mail(updlock) where id = _mail_id and to_id = _char_id

if (@_rowcount = 0)

begin

	select _item_id, _money, _ap

	rollback tran

	return 1		-- invalid key

end



-- check 

if (_flag = 0)

begin	-- get item

	if (_item_id = 0)

	begin

		select _item_id, _money, _ap

		rollback tran

		return 2		-- no attached item

	end

end

else if (_flag = 1)

begin	-- get money

	if (_money = 0)

	begin

		select _item_id, _money, _ap

		rollback tran

		return 2		-- no attached item

	end

end

else if (_flag = 2)

begin  -- get ap

	if (_ap = 0)

	begin

		select _item_id, _money, _ap

		rollback tran

		return 2		-- no attached item

	end

end



-- update

if (_flag = 0)

begin	-- clear item



	-- update user_item table

	update user_item set warehouse = _warehouse where id = _item_id



	-- update user_mail table

	update user_mail set item_id = 0, item_nameid = 0, item_amount = 0 where id = _mail_id

end

else if (_flag = 1)

begin	-- clear money



	-- update user_mail table

	update user_mail set money = 0 where id = _mail_id

end

else if (_flag = 2)

begin	-- clear ap



	-- update user_mail table

	update user_mail set abyss_point = 0 where id = _mail_id

end



-- output 

select _item_id, _money, _ap



commit tran



return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetitem;
-- +goose StatementEnd
