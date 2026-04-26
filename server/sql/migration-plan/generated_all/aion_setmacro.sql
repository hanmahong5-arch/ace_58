-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetMacro.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmacro(_char_id INTEGER, _slot_id INTEGER, _data TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT char_id FROM user_macro(updlock) WHERE char_id = _char_id and  slot_id = _slot_id)

begin

	UPDATE user_macro SET data = _data WHERE char_id = _char_id and  slot_id = _slot_id

end

else

begin

	INSERT user_macro (char_id, slot_id, data) VALUES (_char_id, _slot_id, _data)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmacro;
-- +goose StatementEnd
