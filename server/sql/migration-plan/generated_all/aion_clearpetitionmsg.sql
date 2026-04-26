-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ClearPetitionMsg.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearpetitionmsg(_char_id INTEGER, _pet_sv_id INTEGER, _local_sv INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




IF _pet_sv_id = _local_sv

	UPDATE user_data SET petition_msg = NULL WHERE char_id = _char_id

ELSE

BEGIN

	--IF EXISTS (SELECT id FROM user_petition_msg(updlock) WHERE char_id = _char_id AND petition_sv_id = _pet_sv_id)

	--BEGIN

		DELETE FROM user_petition_msg WHERE char_id = _char_id AND petition_sv_id = _pet_sv_id

	--END

END




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearpetitionmsg;
-- +goose StatementEnd
