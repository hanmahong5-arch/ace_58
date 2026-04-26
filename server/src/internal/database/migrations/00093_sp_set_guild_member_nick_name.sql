-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_SetGuildMemberNickName.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildMemberNickName.sql
--
-- Updates user_data.guild_nickname for a given char_id, but only if the
-- character actually belongs to the supplied guild_id. Stamps change_info_time.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmembernickname(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildmembernickname(
    _guild_id              INTEGER,
    _char_id               INTEGER,
    _guild_member_nickname TEXT
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET guild_nickname   = _guild_member_nickname,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW(), 0)
     WHERE char_id = _char_id AND guild_id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmembernickname(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd
