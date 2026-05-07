-- AionCore 5.8 — Sprint 1.1a batch 5 port: aion_GetEmotionList (login emote-slot hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetEmotionList.sql
-- Original (T-SQL):
--   SELECT emotion_type, expire_date
--   FROM user_emotion
--   WHERE char_id=@nCharId
--
-- Schema delta:
--   Round 10 (00115) scaffolded user_emotion with the bare minimum that
--   aion_DeleteEmotion (00123) needed: (char_id, emotion_id, emotion_type,
--   expire_time TIMESTAMPTZ). NCSoft's source SP returns `expire_date`
--   (BIGINT unix-epoch seconds — set by application code), not a wall-clock
--   timestamp. To preserve the byte-perfect on-the-wire semantics the 5.8
--   client expects, we additively widen the table with a BIGINT `expire_date`
--   column. The legacy TIMESTAMPTZ column is kept (still NULL-able, no row
--   touched) so 00115/00123 keep working untouched and a future SetEmotion
--   port can decide whether to retire it.
--
-- Translation notes:
--   * `expire_date` is BIGINT (unix epoch seconds) per NCSoft semantics —
--     deliberately NOT TIMESTAMPTZ. Lua/Go side handles timezone arithmetic;
--     storing as bigint avoids round-trip drift between server tick and PG.
--   * No ORDER BY in the source — the wire format is order-insensitive
--     (client builds a hash on emotion_type). We add ORDER BY emotion_type
--     for deterministic test output, which is a strict superset of original.
--   * Function declared STABLE — pure read, planner can inline.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- emote slot hydration on login

-- +goose Up
-- +goose StatementBegin
-- Additive widening: expire_date stores NCSoft-native unix-epoch seconds.
ALTER TABLE user_emotion
    ADD COLUMN IF NOT EXISTS expire_date BIGINT NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getemotionlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getemotionlist(_char_id INTEGER)
RETURNS TABLE (
    emotion_type SMALLINT,
    expire_date  BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ue.emotion_type, ue.expire_date
          FROM user_emotion ue
         WHERE ue.char_id = _char_id
         ORDER BY ue.emotion_type ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getemotionlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_emotion
    DROP COLUMN IF EXISTS expire_date;
-- +goose StatementEnd
