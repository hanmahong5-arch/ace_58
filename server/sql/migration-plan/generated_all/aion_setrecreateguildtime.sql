-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetRecreateGuildTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setrecreateguildtime(_char_i_d INTEGER, _recreate_guild_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data

SET recreate_guild_time=_recreate_guild_time,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE char_id=_char_i_d;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setrecreateguildtime;
-- +goose StatementEnd
