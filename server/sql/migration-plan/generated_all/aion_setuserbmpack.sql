-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUserBMPack.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserbmpack(_char_id INTEGER, _pack_type INTEGER, _pack_state INTEGER, _expiration_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




    -- Insert statements for procedure here

	IF EXISTS (SELECT char_id FROM user_bm_pack(updlock) WHERE char_id = _char_id AND pack_type = _pack_type)

		UPDATE user_bm_pack

		SET pack_state = _pack_state,

			expiration_time = _expiration_time

		WHERE char_id = _char_id AND pack_type = _pack_type

	ELSE

		INSERT user_bm_pack(char_id, pack_type, pack_state, expiration_time) VALUES (_char_id, _pack_type, 1, _expiration_time)


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserbmpack;
-- +goose StatementEnd
