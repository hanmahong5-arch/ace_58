-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUserBMPack_20140609.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserbmpack_20140609(_char_id INTEGER, _pack_type INTEGER, _pack_state INTEGER, _expiration_time INTEGER, _unique_param INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




    -- Insert statements for procedure here

	IF EXISTS (SELECT char_id FROM user_bm_pack(updlock) WHERE char_id = _char_id AND pack_type = _pack_type AND unique_param = _unique_param)

		UPDATE user_bm_pack

		SET pack_state = _pack_state,

			expiration_time = _expiration_time

		WHERE char_id = _char_id AND pack_type = _pack_type AND unique_param = _unique_param

	ELSE

		INSERT user_bm_pack(char_id, pack_type, pack_state, expiration_time, unique_param) VALUES (_char_id, _pack_type, 1, _expiration_time, _unique_param)


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserbmpack_20140609;
-- +goose StatementEnd
