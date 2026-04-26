-- AionCore 5.8 — Sprint 1.1a port #2: aion_DeleteGuild.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteGuild.sql
-- Original T-SQL: DELETE guild WHERE id=@nGuildId  (T-SQL allows the missing FROM)
-- Auto-port pass: 100% (converter inserted the FROM). No hand fixes needed
-- beyond promotion to a void function.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguild(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteguild(_guild_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM guild WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguild(INTEGER);
-- +goose StatementEnd
