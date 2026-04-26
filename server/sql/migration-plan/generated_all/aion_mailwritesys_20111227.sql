-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailWriteSys_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailwritesys_20111227(_to_id INTEGER, _to_name TEXT, _from_id INTEGER, _from_name TEXT, _title TEXT, _content TEXT, _item_id BIGINT, _item_nameid INTEGER, _item_amount BIGINT, _money BIGINT, _warehouse INTEGER, _arrive_time INTEGER, _express_mail INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF (_item_id <> 0)

	BEGIN

		UPDATE user_item SET warehouse = _warehouse, char_id = _to_id WHERE id = _item_id

		update user_item_option set char_id = _to_id where id = _item_id

	END



	INSERT INTO user_mail (to_id, to_name, from_id, from_name, title, content, item_id, item_nameid, item_amount, money, arrive_time, express_mail) VALUES(_to_id, _to_name, _from_id, _from_name, _title, _content, _item_id, _item_nameid, _item_amount, _money, _arrive_time, _express_mail)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailwritesys_20111227;
-- +goose StatementEnd
