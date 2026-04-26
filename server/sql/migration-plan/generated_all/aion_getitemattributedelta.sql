-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getitemattributedelta.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemattributedelta(_dbid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, 

		attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value

		from user_item_attribute where id = _dbid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemattributedelta;
-- +goose StatementEnd
