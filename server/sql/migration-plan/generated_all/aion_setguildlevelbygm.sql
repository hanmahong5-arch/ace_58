-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildLevelByGM.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildlevelbygm(_guild_id INTEGER, _level INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild

SET level = _level, 

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildlevelbygm;
-- +goose StatementEnd
