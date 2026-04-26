-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailRead.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailread(_char_id INTEGER, _mail_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select to_id, from_id, from_name, title, content, item_id, item_nameid, item_amount, money, abyss_point, state, arrive_time, express_mail

from user_mail(updlock)

where id = _mail_id



if (@_rowcount > 0)

begin

	update user_mail

	set state = 1

	where id = _mail_id and to_id = _char_id and state = 0

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailread;
-- +goose StatementEnd
