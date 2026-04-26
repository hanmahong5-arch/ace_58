-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_putwallet.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putwallet()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
int

as

insert into user_wallet (char_id, name_id, amount) values (_char_id, 18240001, 0);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putwallet;
-- +goose StatementEnd
