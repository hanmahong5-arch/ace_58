-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteEmotion.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteEmotion.sql
--
-- T-SQL body (note: T-SQL @nEmotionType is smallint, but the column it
-- compares against is also smallint — in PG we declare the parameter as
-- SMALLINT and cast at the boundary so callers can pass plain int literals
-- without explicit cast):
--   DELETE user_emotion
--   WHERE char_id = @nCharId AND emotion_type = @nEmotionType
--
-- Per-emotion-type wipe (not per-emotion-id). Used when admins remove an
-- entire category of emotes (e.g. event emotes after the event ends).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteemotion(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteemotion(
    _char_id      INTEGER,
    _emotion_type INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_emotion
     WHERE char_id      = _char_id
       AND emotion_type = _emotion_type::SMALLINT;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteemotion(INTEGER, INTEGER);
-- +goose StatementEnd
