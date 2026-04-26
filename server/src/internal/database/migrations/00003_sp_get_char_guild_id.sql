-- AionCore 5.8 — Sprint 1.1a port #1: aion_GetCharGuildId.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCharGuildId.sql
-- Original T-SQL: SELECT guild_id FROM user_data WHERE char_id = @nCharId
-- Auto-port pass: 100% mechanical (single SELECT). Hand fix: replaced the
-- generated `RETURNS SETOF RECORD` with explicit `RETURNS TABLE(guild_id INTEGER)`
-- so callers can scan without a column-list cast.

-- +goose Up
-- +goose StatementBegin
-- Drop any prior signature (older sessions may have created it with
-- RETURNS SETOF RECORD which blocks CREATE OR REPLACE — PG raises 42P13).
DROP FUNCTION IF EXISTS aion_getcharguildid(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharguildid(_char_id INTEGER)
RETURNS TABLE(guild_id INTEGER)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT u.guild_id FROM user_data u WHERE u.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharguildid(INTEGER);
-- +goose StatementEnd
