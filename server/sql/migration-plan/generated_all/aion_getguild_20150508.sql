-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuild_20150508.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguild_20150508(_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT name, race, master_id, level, rank, submaster_right, officer_right, member_right, newbie_right, point, fund, this_week_tld, last_week_tld, tld_update_time, delete_requested, delete_time, intro, join_process_type, join_restrict_level

FROM guild

where id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguild_20150508;
-- +goose StatementEnd
