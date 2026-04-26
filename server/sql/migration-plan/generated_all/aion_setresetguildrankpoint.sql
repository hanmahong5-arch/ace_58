-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetResetGuildRankPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setresetguildrankpoint()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild

SET point = 0,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0),

	point_max_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)



delete from abyss_region_ranking;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setresetguildrankpoint;
-- +goose StatementEnd
