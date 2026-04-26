-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetWardrobe.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setwardrobe(_char_id INTEGER, _slot_id INTEGER, _name_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT char_id FROM user_wardrobe(updlock) WHERE char_id = _char_id and  slot_id = _slot_id)

begin

	UPDATE user_wardrobe SET name_id = _name_id WHERE char_id = _char_id and slot_id = _slot_id

end

else

begin

	INSERT user_wardrobe (char_id, slot_id, name_id) VALUES (_char_id, _slot_id, _name_id)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setwardrobe;
-- +goose StatementEnd
