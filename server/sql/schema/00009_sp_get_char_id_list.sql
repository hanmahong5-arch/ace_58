-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_GetCharIdList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCharIdList.sql
-- T-SQL body:
--   SELECT char_id, user_id FROM user_data
--   WHERE account_id=@nAccount AND char_id <= 33550000
--     AND (delete_date = 0
--          OR (delete_date > dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)))
--
-- Used by char-select screen to enumerate an account's chars.
-- delete_date is a Unix-epoch int (set by SetCharDeleteTime); 0 means alive,
-- otherwise the row stays visible until the scheduled deletion arrives.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharidlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharidlist(_account_id INTEGER)
RETURNS TABLE (char_id INTEGER, user_id TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT u.char_id, u.user_id
      FROM user_data u
     WHERE u.account_id = _account_id
       AND u.char_id <= 33550000
       AND (u.delete_date = 0
            OR u.delete_date > GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0));
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharidlist(INTEGER);
-- +goose StatementEnd
