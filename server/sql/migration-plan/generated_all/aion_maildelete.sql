-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailDelete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_maildelete(_char_id INTEGER, _mail_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _item_id int declare _state int _state := 0



SELECT item_id, _state = state INTO _item_id from user_mail(updlock) where id = _mail_id and to_id = _char_id

if (@_rowcount = 0)	-- no data

	select 1, _state



if (_item_id <> 0)

begin

	exec aion_DeleteItem _item_id

end



delete from user_mail

where id = _mail_id and to_id = _char_id



select 0, _state;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_maildelete;
-- +goose StatementEnd
