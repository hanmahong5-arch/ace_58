-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetInstanceExtraCountAbyssOP.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstanceextracountabyssop(_char_id INTEGER, _reset_time BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT map_number, extra_count_abyssop, next_reset_time FROM user_instance_extracount WITH(NOLOCK) WHERE char_id = _char_id AND next_reset_time >= _reset_time


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstanceextracountabyssop;
-- +goose StatementEnd
