-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetInvalidGuildList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinvalidguildlist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select id

from guild g

where (g.master_id = 0 and g.delete_requested = 0) 

	or (g.master_id not in (select char_id from user_data where delete_complete_date=0)	);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinvalidguildlist;
-- +goose StatementEnd
