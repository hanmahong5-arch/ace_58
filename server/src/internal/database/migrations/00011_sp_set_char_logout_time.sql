-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetCharLogoutTime_20120516.
--
-- Resolves Round 4 MISSING entry "aion_PutCharLogout" — NCSoft's name is
-- aion_SetCharLogoutTime_20120516 (decision logged in priority-50.md).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharLogoutTime_20120516.sql
-- Original T-SQL also returns @logoutTime as an OUTPUT param formatted ISO-8601.
-- We return it as a TIMESTAMPTZ so the Lua side can format as needed.
--
-- Side effects: stamps last_logout_time, accumulates playtime by minutes since
-- last_login_time, and bumps change_info_time epoch.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlogouttime_20120516(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlogouttime_20120516(_char_id INTEGER)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql AS $$
DECLARE
    _now TIMESTAMPTZ := NOW();
BEGIN
    UPDATE user_data
       SET last_logout_time = _now,
           playtime         = playtime
                              + GREATEST(0, EXTRACT(EPOCH FROM (_now - last_login_time))::INTEGER / 60),
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
    RETURN _now;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlogouttime_20120516(INTEGER);
-- +goose StatementEnd
