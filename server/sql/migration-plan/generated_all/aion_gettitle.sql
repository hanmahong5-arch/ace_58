-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetTitle.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gettitle(_user_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT title_id, is_have, expired_time FROM user_title WHERE char_id=_user_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gettitle;
-- +goose StatementEnd
