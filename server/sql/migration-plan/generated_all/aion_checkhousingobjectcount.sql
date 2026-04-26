-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CheckHousingObjectCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkhousingobjectcount()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




--	SELECT rows FROM sysindexes WHERE id = OBJECT_ID('houseobject') AND indid < 2

	SELECT MAX(id) FROM houseobject



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkhousingobjectcount;
-- +goose StatementEnd
