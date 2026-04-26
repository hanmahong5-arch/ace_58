-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildDispers.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguilddispers(_guild_id INTEGER, _delete__time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild

SET delete_requested=1, delete_time=_delete__time,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguilddispers;
-- +goose StatementEnd
