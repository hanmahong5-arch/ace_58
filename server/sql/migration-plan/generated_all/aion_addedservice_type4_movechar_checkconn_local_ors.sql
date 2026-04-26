-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_CheckConn_local_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_checkconn_local_ors()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select 0 as result;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_checkconn_local_ors;
-- +goose StatementEnd
