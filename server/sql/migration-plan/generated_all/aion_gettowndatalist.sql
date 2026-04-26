-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetTownDataList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gettowndatalist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT town_id, point, lastLvChangedTime FROM town_data WITH(NOLOCK)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gettowndatalist;
-- +goose StatementEnd
