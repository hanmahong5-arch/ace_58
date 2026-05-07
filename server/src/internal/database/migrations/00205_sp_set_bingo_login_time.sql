-- AionCore 5.8 — Sprint 1.1a batch 14 port: aion_SetBingoLoginTime (bingo last-login stamp).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetBingoLoginTime.sql
-- Original (T-SQL):
--   UPDATE user_app_installation
--      SET login_time = @login_time
--    WHERE char_id   = @char_id
--
-- Translation notes:
--   * Naked UPDATE — if the row is missing the SP silently no-ops (0 rows
--     affected). NCSoft never INSERTs from this SP; the row is created by
--     PutCanMakeSticker (00091) and PutBingoMissionData. Bug-for-bug pinned.
--   * `user_app_installation` table already exists from migration 00072
--     (pve_scaffold_round5). We add no columns here.
--   * `login_time` is INTEGER (unix-epoch seconds). NCSoft uses int4 even
--     though MS-SQL server allows DATETIME — the column was minted as int
--     so callers can compute deltas without TZ math.
--   * Returns rows-affected (0 or 1) for caller observability.
--
-- Bug-for-bug:
--   * Missing row is silently swallowed. Caller is responsible for ensuring
--     the row exists (PutCanMakeSticker minted it on first sticker-shop entry).
--
-- Used by:
--   scripts/handlers/cm_bingo_login.lua  (Q3 — bingo daily login bookkeeping)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setbingologintime(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setbingologintime(
    _char_id     INTEGER,
    _login_time  INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Naked UPDATE; bug-for-bug no INSERT-on-missing-row.
    UPDATE user_app_installation
       SET login_time = _login_time
     WHERE char_id   = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setbingologintime(INTEGER, INTEGER);
-- +goose StatementEnd
