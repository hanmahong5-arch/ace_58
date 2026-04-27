-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_GetCharInfoBasic.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCharInfoBasic.sql
--
-- T-SQL body:
--   SELECT account_id, class, guild_id, user_id, guild_rank
--   FROM user_data WHERE char_id = @nCharId
--
-- Light-weight char-id resolver used by chat/friend/guild systems where
-- the heavy GetCharInfo_20160818 (120 columns) would be wasteful. Returns
-- exactly five columns — keep them in NCSoft order so the wire-side
-- consumer (Lua handler) can zero-copy positional scan.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharinfobasic(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharinfobasic(_char_id INTEGER)
RETURNS TABLE (
    account_id INTEGER,
    class      SMALLINT,
    guild_id   INTEGER,
    user_id    TEXT,
    guild_rank INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT ud.account_id, ud.class, ud.guild_id, ud.user_id, ud.guild_rank
          FROM user_data ud
         WHERE ud.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharinfobasic(INTEGER);
-- +goose StatementEnd
