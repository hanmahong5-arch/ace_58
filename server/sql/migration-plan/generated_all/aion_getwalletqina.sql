-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getwalletqina.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getwalletqina()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
int

as

select ID,amount from user_wallet where char_id=_char_id and name_id=18240001;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwalletqina;
-- +goose StatementEnd
