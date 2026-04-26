-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDispersedGuildList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdispersedguildlist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select id, delete_requested, delete_time

from guild

where delete_requested=1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdispersedguildlist;
-- +goose StatementEnd
