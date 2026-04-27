-- AionCore 5.8 — name → char_id lookup SP.
--
-- No NCSoft equivalent. The 5.8 SQL Server build resolves recipient names
-- inside aion_GetCharInfo_20160818 (full 120-col fetch) or via tactical
-- ad-hoc queries from the GM tool. The runtime mail / friend / whisper paths
-- need a focused name → char_id lookup that does NOT pay GetCharInfo cost.
--
-- Used by:
--   scripts/lib/mail.lua    -- recipient resolution on player→player send
--                            (mail handler returns "no_recipient" when 0 rows)
--
-- Future callers (deferred until those features land):
--   - friend system add-by-name
--   - whisper / private message routing
--   - guild invite by character name
--
-- Returns 0 rows when the name is unknown OR the matching char is soft-
-- deleted; 1 row otherwise. Names in user_data are unique (NCSoft enforces
-- this with a unique index on `name`), so we never need ORDER BY/LIMIT.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharidbyname(TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharidbyname(_name TEXT)
RETURNS TABLE (
    char_id INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ud.char_id
          FROM user_data ud
         WHERE ud.name        = _name
           AND ud.delete_date = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharidbyname(TEXT);
-- +goose StatementEnd
