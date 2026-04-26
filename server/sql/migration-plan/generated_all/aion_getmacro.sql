-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetMacro.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmacro(_char_id INTEGER, _slot_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
--IF (_slot_id = -1)

	SELECT slot_id, data FROM user_macro WHERE char_id = _char_id

--ELSE

--	SELECT slot_id, data FROM user_macro WHERE char_id = _char_id and slot_id = _slot_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmacro;
-- +goose StatementEnd
