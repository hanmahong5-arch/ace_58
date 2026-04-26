-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildJoinProcessType.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildjoinprocesstype(_guild_id INTEGER, _join_process_type INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild 

SET join_process_type = _join_process_type	

WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildjoinprocesstype;
-- +goose StatementEnd
