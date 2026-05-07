-- AionCore 5.8 — Sprint 1.1a batch 19 port: aion_SetCaptchaInfo
-- (anti-bot captcha state UPSERT — IF EXISTS UPDATE ELSE INSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCaptchaInfo.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT char_id FROM user_captcha (updlock) WHERE char_id=@nCharId)
--       UPDATE user_captcha
--          SET prohibition_flag=@nProhibitionFlag, count=@nCount,
--              prohibition_time=@nProhibitionTime, elapsed_time=@nElapsedTime,
--              first_generation_time=@nFirstGenerationTime
--        WHERE char_id=@nCharId
--   ELSE
--       INSERT user_captcha(char_id, prohibition_flag, count, prohibition_time,
--                           elapsed_time, first_generation_time)
--       VALUES (@nCharId, @nProhibitionFlag, @nCount, @nProhibitionTime,
--               @nElapsedTime, @nFirstGenerationTime)
--
-- Translation notes:
--   * Classic NCSoft "IF EXISTS UPDATE ELSE INSERT" pattern. PG idiom is
--     INSERT ... ON CONFLICT (char_id) DO UPDATE — semantically identical,
--     and atomic without the (updlock) hint that T-SQL needs.
--   * Parameter widths verified against NCSoft schema (TINYINT widens to
--     SMALLINT in PG — 5.8 client reads as uint8 via the RPC layer; widening
--     is invisible on the wire):
--       @nCharId                INT     → INTEGER
--       @nProhibitionFlag       TINYINT → SMALLINT  (0/1)
--       @nCount                 TINYINT → SMALLINT  (0..255 effective range)
--       @nProhibitionTime       INT     → INTEGER   (epoch seconds)
--       @nElapsedTime           INT     → INTEGER   (cumulative challenge time)
--       @nFirstGenerationTime   INT     → INTEGER   (epoch seconds)
--   * VOLATILE — data-modifying.
--   * No row count returned. Caller cannot distinguish INSERT from UPDATE
--     branch — pinned (NCSoft behaves the same).
--
-- Bug-for-bug:
--   * No CHECK on @nProhibitionFlag (TINYINT permits 0..255; NCSoft uses
--     it as boolean but the column accepts anything). Pinned — do NOT add
--     CHECK constraint.
--   * Re-issuing with identical payload still triggers UPDATE (no early-
--     return short-circuit). NCSoft pin.
--   * elapsed_time / first_generation_time are caller-supplied (not
--     auto-incremented or set by NOW()). Pinned — caller decides clock.
--   * No FK to user_data(char_id). Orphan rows can survive char delete
--     until they collide on char_id reuse. NCSoft mirrors.
--
-- Used by:
--   scripts/handlers/cm_captcha_answer.lua    (record answer + cooldown)
--   scripts/handlers/cm_login.lua             (reset elapsed on session start)
--   scripts/lib/captcha.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcaptchainfo(INTEGER, SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcaptchainfo(
    _char_id                INTEGER,
    _prohibition_flag       SMALLINT,
    _count                  SMALLINT,
    _prohibition_time       INTEGER,
    _elapsed_time           INTEGER,
    _first_generation_time  INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- T-SQL "IF EXISTS UPDATE ELSE INSERT" → PG UPSERT, atomic via PK.
    -- (updlock) hint is unneeded in PG; ON CONFLICT is concurrency-safe.
    INSERT INTO user_captcha (
        char_id, prohibition_flag, count,
        prohibition_time, elapsed_time, first_generation_time
    ) VALUES (
        _char_id, _prohibition_flag, _count,
        _prohibition_time, _elapsed_time, _first_generation_time
    )
    ON CONFLICT (char_id) DO UPDATE
       SET prohibition_flag      = EXCLUDED.prohibition_flag,
           count                 = EXCLUDED.count,
           prohibition_time      = EXCLUDED.prohibition_time,
           elapsed_time          = EXCLUDED.elapsed_time,
           first_generation_time = EXCLUDED.first_generation_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcaptchainfo(INTEGER, SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
