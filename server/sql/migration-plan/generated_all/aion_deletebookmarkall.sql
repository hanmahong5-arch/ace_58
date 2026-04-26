-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteBookmarkAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletebookmarkall(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM bookmark WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletebookmarkall;
-- +goose StatementEnd
