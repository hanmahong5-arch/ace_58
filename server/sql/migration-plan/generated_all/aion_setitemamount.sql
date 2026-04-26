-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemAmount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemamount(_id BIGINT, _amount BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item SET amount = _amount WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemamount;
-- +goose StatementEnd
