-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPetitionMsg.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetitionmsg(_char_id INTEGER, _pet_sv_id INTEGER, _local_sv INTEGER, _pet_msg TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




IF _pet_sv_id = _local_sv

	UPDATE user_data SET petition_msg = _pet_msg WHERE char_id = _char_id

ELSE

BEGIN

	IF EXISTS (SELECT id FROM user_petition_msg(updlock) WHERE char_id = _char_id AND petition_sv_id = _pet_sv_id)

		UPDATE user_petition_msg SET msg = _pet_msg WHERE char_id = _char_id AND petition_sv_id = _pet_sv_id

	ELSE

		INSERT INTO user_petition_msg VALUES (_char_id, _pet_sv_id, _pet_msg)

END




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetitionmsg;
-- +goose StatementEnd
