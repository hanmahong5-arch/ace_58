-- AionCore 5.8 — Sprint 1.1a batch 13 port: aion_PutEmotion (emotion slot writer).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutEmotion.sql
-- Original (T-SQL):
--   BEGIN TRANSACTION
--   if EXISTS (SELECT char_id FROM user_emotion(UPDLOCK)
--              WHERE char_id=@nCharId AND emotion_type=@nEmotionType)
--       UPDATE user_emotion SET expire_date=@nExpireDate
--        WHERE char_id=@nCharId AND emotion_type=@nEmotionType
--   else
--       INSERT user_emotion(char_id, emotion_type, expire_date)
--       VALUES (@nCharId, @nEmotionType, @nExpireDate)
--   COMMIT TRANSACTION
--
-- Translation notes:
--   * NCSoft keys the row on (char_id, emotion_type), not (char_id, emotion_id).
--     Round 7 scaffold (00115) created `user_emotion` with PK (char_id, emotion_id)
--     because GetEmotionList (00159) needed a per-row identity. NCSoft itself
--     never carries emotion_id — at most one row per (char_id, emotion_type).
--     We preserve that invariant by adding a UNIQUE on (char_id, emotion_type).
--     emotion_id continues to default to 0 in the NCSoft path; future ports
--     that key on emotion_id will set it explicitly.
--   * `expire_date` is BIGINT (unix epoch seconds) — added by 00159's ALTER.
--     `expire_time` (TIMESTAMPTZ legacy from R7) is left untouched, NULL OK.
--   * IF EXISTS pattern preserved verbatim via UPSERT on the new UNIQUE index.
--     ON CONFLICT… DO UPDATE matches the lookup-then-write flow byte-for-byte
--     (single statement, atomic; lighter than the T-SQL UPDLOCK + transaction).
--   * @nEmotionType is SMALLINT in T-SQL; @nExpireDate is INT (unix epoch).
--     NCSoft will overflow @nExpireDate at 2038 — they ship a separate column
--     widening then. We accept BIGINT here so 2038 never bites; client passes
--     an INT-sized value, PG widens at the boundary.
--   * Return rows-affected (1 = inserted-or-updated; UPSERT always touches a row).
--
-- Used by:
--   scripts/handlers/cm_emotion.lua  -- on /emote unlock & on event grant
--   scripts/lib/emotion.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_emotion — add UNIQUE (char_id, emotion_type) so the NCSoft per-type
-- single-row invariant is enforced. PK on (char_id, emotion_id) stays for
-- backward-compat with 00115/00159; emotion_id stays 0 on NCSoft path.
-- ====================================================================
ALTER TABLE user_emotion
    ADD CONSTRAINT user_emotion_char_type_uniq UNIQUE (char_id, emotion_type);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putemotion(INTEGER, SMALLINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putemotion(
    _char_id      INTEGER,
    _emotion_type SMALLINT,
    _expire_date  BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- UPSERT on (char_id, emotion_type).  NCSoft 真表无 emotion_id 这一列；
    -- R7 (00115) 给 PG 加了 (char_id, emotion_id) PK，所以这里把 emotion_id
    -- 镜像到 emotion_type — 两个键空间是 1:1，PK 冲突 ↔ UNIQUE 冲突 同步发生，
    -- ON CONFLICT 走两条任一约束都能 UPDATE；emotion_id := emotion_type 让
    -- 不同 type 的 PUT 落在不同 PK 槽位，多行共存。
    INSERT INTO user_emotion (char_id, emotion_id, emotion_type, expire_date)
    VALUES (_char_id, _emotion_type::INTEGER, _emotion_type, _expire_date)
    ON CONFLICT ON CONSTRAINT user_emotion_char_type_uniq
    DO UPDATE SET expire_date = EXCLUDED.expire_date;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putemotion(INTEGER, SMALLINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_emotion
    DROP CONSTRAINT IF EXISTS user_emotion_char_type_uniq;
-- +goose StatementEnd
