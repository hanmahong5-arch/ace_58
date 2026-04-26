-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildIntro.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildintro(_guild_id INTEGER, _intro TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild 

SET intro = _intro	

WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildintro;
-- +goose StatementEnd
