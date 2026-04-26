-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailSetRead.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailsetread(_char_id INTEGER, _mail_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
update user_mail

set state = 1

where id = _mail_id and to_id = _char_id and state = 0



if (@_rowcount = 0)

	return 1		-- error. invalid key




return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailsetread;
-- +goose StatementEnd
