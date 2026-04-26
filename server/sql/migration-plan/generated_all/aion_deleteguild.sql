-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteGuild.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteguild(_guild_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM guild WHERE id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguild;
-- +goose StatementEnd
