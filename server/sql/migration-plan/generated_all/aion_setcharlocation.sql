-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLocation.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlocation(_char_id INTEGER, _cur_server INTEGER, _world INTEGER, _x_location DOUBLE PRECISION, _y_location DOUBLE PRECISION, _z_location DOUBLE PRECISION)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data SET cur_server = _cur_server, world = _world, xlocation = _x_location, ylocation = _y_location, zlocation = _z_location WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocation;
-- +goose StatementEnd
