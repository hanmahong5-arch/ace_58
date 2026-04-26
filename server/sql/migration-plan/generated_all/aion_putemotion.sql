-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutEmotion.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putemotion(_char_id INTEGER, _emotion_type INTEGER, _expire_date INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN TRANSACTION


if EXISTS (SELECT char_id FROM user_emotion(UPDLOCK) WHERE char_id=_char_id and emotion_type=_emotion_type) 

begin

	UPDATE user_emotion

	SET expire_date = _expire_date

	WHERE char_id=_char_id and emotion_type=_emotion_type

end

else

begin

	INSERT user_emotion(char_id, emotion_type, expire_date)	

	VALUES (_char_id, _emotion_type, _expire_date)	

end


COMMIT TRANSACTION



/* Get */

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putemotion;
-- +goose StatementEnd
