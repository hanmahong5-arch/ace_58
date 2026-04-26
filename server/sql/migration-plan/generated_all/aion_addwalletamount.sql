-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_addwalletamount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addwalletamount(_id BIGINT, _add BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_wallet set amount=amount+_add where ID = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addwalletamount;
-- +goose StatementEnd
