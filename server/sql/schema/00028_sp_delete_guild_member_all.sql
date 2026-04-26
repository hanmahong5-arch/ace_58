-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_DeleteGuildMemberAll.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteGuildMemberAll.sql
-- Wipes the guild link from every member when the legion disbands.
-- T-SQL uses an inner-LOOP-join on (a) → (b) for query-plan reasons. PG
-- planner doesn't need that hint — a plain UPDATE...WHERE is equivalent.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguildmemberall(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteguildmemberall(_guild_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET guild_id          = 0,
           guild_rank        = 0,
           guild_intro       = '',
           guild_update_date = NOW()
     WHERE guild_id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguildmemberall(INTEGER);
-- +goose StatementEnd
