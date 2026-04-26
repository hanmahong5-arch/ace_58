-- AionCore 5.8 — Sprint 1.1a port #5: aion_SetGuildMember.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildMember.sql
-- Original T-SQL flow:
--   UPDATE user_data SET guild_id=@nGuildId, guild_update_date=GetDate(),
--          change_info_time=dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)
--   WHERE char_id=@nCharId
--   DECLARE @ret int
--   SELECT @ret = guild_id FROM user_data WHERE char_id=@nCharId
--   RETURN @ret
--
-- Auto-port pass: 70% — the converter handled @vars and date funcs but the
-- T-SQL `RETURN <int>` and the inline `DECLARE @ret int` need restructuring
-- in plpgsql (DECLARE goes in its own block, not inline). Hand-fixed below.
--
-- Note on Lua call sites: aion_SetGuildMember is invoked 5 times across
-- scripts/lib/legion.lua. The Lua code currently ignores the return value
-- so RETURNS INTEGER is a strict superset of what callers need.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmember(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildmember(
    _guild_id INTEGER,
    _char_id  INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    _ret INTEGER;
BEGIN
    UPDATE user_data
       SET guild_id          = _guild_id,
           guild_update_date = NOW(),
           change_info_time  = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;

    SELECT u.guild_id INTO _ret FROM user_data u WHERE u.char_id = _char_id;
    RETURN _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmember(INTEGER, INTEGER);
-- +goose StatementEnd
