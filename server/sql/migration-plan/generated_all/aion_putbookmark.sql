-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutBookmark.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putbookmark(_char_id INTEGER, _bookmark TEXT, _world INTEGER, _x DOUBLE PRECISION, _y DOUBLE PRECISION, _z DOUBLE PRECISION)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT bookmark (char_id, bookmark, world, x, y, z) 

	VALUES (_char_id, _bookmark, _world, _x, _y, _z);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbookmark;
-- +goose StatementEnd
