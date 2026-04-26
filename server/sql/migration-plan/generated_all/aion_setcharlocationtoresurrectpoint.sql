-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLocationToResurrectPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlocationtoresurrectpoint(_name TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data SET  xlocation = resurrect_xlocation, ylocation = resurrect_ylocation, zlocation = resurrect_zlocation WHERE user_id = _name;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocationtoresurrectpoint;
-- +goose StatementEnd
