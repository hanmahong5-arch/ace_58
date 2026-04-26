-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUseCP.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setusecp(_char_id INTEGER, _category INTEGER, _enchant_object_id INTEGER, _value INTEGER, _accumulated_cp INTEGER, _data_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	IF EXISTS (SELECT char_id FROM user_use_cp (UPDLOCK) WHERE char_id = _char_id AND category = _category AND enchant_object_id = _enchant_object_id) 

	BEGIN

	UPDATE user_use_cp

	SET value = _value,

		accumulated_cp = _accumulated_cp,

		data_id = _data_id

	WHERE char_id = _char_id AND category = _category AND enchant_object_id = _enchant_object_id

END

ELSE

	BEGIN

		INSERT user_use_cp

		VALUES (_char_id, _category, _enchant_object_id, _value, _accumulated_cp, _data_id)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setusecp;
-- +goose StatementEnd
