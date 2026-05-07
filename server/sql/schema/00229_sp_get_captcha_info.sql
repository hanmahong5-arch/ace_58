-- AionCore 5.8 — Sprint 1.1a batch 19 port: aion_GetCaptchaInfo
-- (anti-bot captcha state SELECT — gates account on prohibition lockout).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCaptchaInfo.sql
-- Original (T-SQL):
--   SELECT prohibition_flag, user_captcha.count, prohibition_time,
--          elapsed_time, first_generation_time
--     FROM user_captcha WHERE char_id=@nCharId
--
-- Translation notes:
--   * Single-row SELECT on user_captcha by PK (char_id). Returns 0 rows
--     when the character has never triggered the captcha pipeline; caller
--     treats no-row as "fresh state, no prohibition".
--   * `user_captcha` table is **first introduced here** (domain not touched
--     by any prior batch). Column shapes pinned to NCSoft 5.8:
--       char_id                INT     → INTEGER PK
--       prohibition_flag       TINYINT → SMALLINT (0/1 boolean-as-tinyint)
--       count                  TINYINT → SMALLINT (consecutive failure count;
--                                                  >0 implies bot suspicion)
--       prohibition_time       INT     → INTEGER (epoch seconds when lockout
--                                                  ends; 0 == not locked)
--       elapsed_time           INT     → INTEGER (cumulative time on captcha
--                                                  challenges across session)
--       first_generation_time  INT     → INTEGER (epoch when current cycle
--                                                  began; reset by SetCaptchaInfo)
--   * Stable column order matches T-SQL. RPC layer in Go reads:
--       (prohibition_flag, count, prohibition_time, elapsed_time, first_generation_time)
--     Do NOT reorder — Go scan is positional.
--   * STABLE function — pure read, safe to inline / cache within a session.
--
-- Bug-for-bug:
--   * Original uses bare `user_captcha.count` (qualified) because COUNT is
--     a reserved-ish word. PG accepts `count` unquoted; pinned without
--     qualification (PG behaviour identical, no need for ceremony).
--   * Returns 0 rows when char_id missing; NCSoft never INSERTs a default
--     row at character-create time. Caller-side null handling required.
--   * No JOIN, no filter on prohibition_flag — caller decides whether the
--     state is actionable.
--
-- Used by:
--   scripts/handlers/cm_login.lua            (gate at session start)
--   scripts/lib/captcha.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_captcha — first introduction. One row per char who ever triggered
-- captcha state. char_id is PK (single-row UPSERT contract via 00230).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_captcha (
    char_id                INTEGER  PRIMARY KEY,
    prohibition_flag       SMALLINT NOT NULL DEFAULT 0,
    count                  SMALLINT NOT NULL DEFAULT 0,
    prohibition_time       INTEGER  NOT NULL DEFAULT 0,
    elapsed_time           INTEGER  NOT NULL DEFAULT 0,
    first_generation_time  INTEGER  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcaptchainfo(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcaptchainfo(
    _char_id INTEGER
) RETURNS TABLE (
    prohibition_flag       SMALLINT,
    count                  SMALLINT,
    prohibition_time       INTEGER,
    elapsed_time           INTEGER,
    first_generation_time  INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    -- Pure SELECT by PK, returns 0 or 1 row. Column order pinned per
    -- T-SQL contract — RPC layer scans positionally.
    RETURN QUERY
    SELECT uc.prohibition_flag, uc.count, uc.prohibition_time,
           uc.elapsed_time, uc.first_generation_time
      FROM user_captcha uc
     WHERE uc.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcaptchainfo(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_captcha;
-- +goose StatementEnd
