-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUserItemSignature.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuseritemsignature(_char_id INTEGER, _signature BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin




	if exists (select char_id from user_item_signature (updlock) where char_id = _char_id)

		UPDATE user_item_signature

		SET signature = _signature

		WHERE char_id = _char_id

	else

		insert user_item_signature(char_id, signature)

		values (_char_id, _signature)




end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuseritemsignature;
-- +goose StatementEnd
