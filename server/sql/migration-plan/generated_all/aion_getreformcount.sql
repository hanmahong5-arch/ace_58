-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetReformCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getreformcount(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT 

		next_reset_time, 

		reform_count

	FROM 

		user_reform 

	WHERE char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getreformcount;
-- +goose StatementEnd
