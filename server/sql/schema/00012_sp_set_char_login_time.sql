-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetCharLoginTime_20120516.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharLoginTime_20120516.sql
-- Stamps last_login_time and bumps change_info_time. Required by the daily-
-- reset logic and by SetCharLogoutTime (which subtracts last_login_time to
-- compute play minutes).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlogintime_20120516(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlogintime_20120516(_char_id INTEGER)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql AS $$
DECLARE
    _now TIMESTAMPTZ := NOW();
BEGIN
    UPDATE user_data
       SET last_login_time = _now,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
    RETURN _now;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlogintime_20120516(INTEGER);
-- +goose StatementEnd
