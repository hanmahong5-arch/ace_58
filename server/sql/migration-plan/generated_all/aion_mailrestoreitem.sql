-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailRestoreItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailrestoreitem(_char_id INTEGER, _mail_id INTEGER, _item_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
declare _name_id int

declare _item_amount int



BEGIN TRANSACTION



SELECT name_id, _item_amount=amount INTO _name_id  from user_item(UPDLOCK) where id = _item_id and char_id = _char_id

if (@_rowcount = 0)

begin

	ROLLBACK TRANSACTION

	return 1 	

end



-- item의 Warehouse를 바꿔줌

update user_item set warehouse = 5 where id=_item_id and char_id = _char_id



COMMIT TRANSACTION



-- item을 다시 메일로 돌려줌

update user_mail set item_id = _item_id, item_nameid = _name_id, item_amount = _item_amount  where id = _mail_id




return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailrestoreitem;
-- +goose StatementEnd
