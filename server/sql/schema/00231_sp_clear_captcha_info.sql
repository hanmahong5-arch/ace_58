-- AionCore 5.8 — Sprint 1.1a batch 19 port: aion_ClearCaptchaInfo
-- (full-table wipe of user_captcha — daily-reset / GM-trigger sweep).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClearCaptchaInfo.sql
-- Original (T-SQL):
--   DELETE FROM user_captcha;
--   --TRUNCATE TABLE user_captcha
--
-- Translation notes:
--   * No parameters. Full-table DELETE (not TRUNCATE — NCSoft commented
--     out the TRUNCATE variant, presumably because TRUNCATE in T-SQL
--     skips triggers and resets identity / breaks audit log on the
--     replicated reporting DB). PG side mirrors: keep DELETE, do not
--     "optimise" to TRUNCATE.
--   * Returns rows-affected (BIGINT — DELETE row count can exceed INT on
--     a long-lived live shard). PG GET DIAGNOSTICS row_count is BIGINT.
--   * VOLATILE — data-modifying.
--   * Used as a GM-only / scheduler-only sweep. Not exposed on the player
--     RPC surface — captcha state is per-char and player-driven via
--     SetCaptchaInfo / GetCaptchaInfo.
--
-- Bug-for-bug:
--   * Wipes ALL chars unconditionally (no WHERE). NCSoft pin — this is
--     the daily-reset path. Caller MUST ensure invocation context (e.g.
--     scheduled job at server-tick boundary, never from a player handler).
--   * No transaction guard, no archival to a history table. Pinned —
--     captcha state is ephemeral; loss is not a defect.
--   * NCSoft kept the TRUNCATE variant as a comment for emergency manual
--     ops. We preserve the DELETE-only behaviour; comment in source above
--     documents the pin.
--
-- Used by:
--   scripts/lib/captcha.lua            (scheduled daily-reset entry)
--   admin REST: POST /admin/captcha/reset (GM tooling, gated)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearcaptchainfo();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearcaptchainfo()
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt BIGINT;
BEGIN
    -- Full-table wipe per NCSoft pin. TRUNCATE intentionally NOT used
    -- (mirrors T-SQL `--TRUNCATE TABLE user_captcha` comment).
    DELETE FROM user_captcha;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearcaptchainfo();
-- +goose StatementEnd
