-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetGuildMemberRank.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildMemberRank.sql
-- Update one member's guild_rank (promote / demote). The (char_id AND guild_id)
-- WHERE clause guards against a stale call where the char already left.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmemberrank(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildmemberrank(
    _guild_id INTEGER, _char_id INTEGER, _rank INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET guild_rank       = _rank,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id AND guild_id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmemberrank(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
