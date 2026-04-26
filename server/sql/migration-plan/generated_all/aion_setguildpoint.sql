-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildpoint(_guild_id INTEGER, _point BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild

SET point = _point,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0),

	point_max_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildpoint;
-- +goose StatementEnd
