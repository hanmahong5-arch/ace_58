-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DelMacro.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_delmacro(_char_id INTEGER, _slot_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_macro WHERE char_id = _char_id AND slot_id = _slot_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_delmacro;
-- +goose StatementEnd
