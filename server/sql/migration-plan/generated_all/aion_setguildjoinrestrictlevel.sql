-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildJoinRestrictLevel.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildjoinrestrictlevel(_guild_id INTEGER, _join_restrict_level INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild 

SET join_restrict_level = _join_restrict_level	

WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildjoinrestrictlevel;
-- +goose StatementEnd
