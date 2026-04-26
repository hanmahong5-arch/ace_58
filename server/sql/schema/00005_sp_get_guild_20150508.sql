-- AionCore 5.8 — Sprint 1.1a port #3: aion_GetGuild_20150508.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetGuild_20150508.sql
-- Original T-SQL: SELECT 19 columns FROM guild WHERE id=@nGuildId
-- Auto-port pass: column list mechanical. Hand fix: explicit RETURNS TABLE
-- with the 19 typed columns matching `guild` schema in 00002_pve_scaffold.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguild_20150508(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguild_20150508(_guild_id INTEGER)
RETURNS TABLE(
    name                TEXT,
    race                INTEGER,
    master_id           INTEGER,
    level               INTEGER,
    rank                INTEGER,
    submaster_right     INTEGER,
    officer_right       INTEGER,
    member_right        INTEGER,
    newbie_right        INTEGER,
    point               BIGINT,
    fund                BIGINT,
    this_week_tld       INTEGER,
    last_week_tld       INTEGER,
    tld_update_time     INTEGER,
    delete_requested    INTEGER,
    delete_time         INTEGER,
    intro               TEXT,
    join_process_type   INTEGER,
    join_restrict_level INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT g.name, g.race, g.master_id, g.level, g.rank,
           g.submaster_right, g.officer_right, g.member_right, g.newbie_right,
           g.point, g.fund,
           g.this_week_tld, g.last_week_tld, g.tld_update_time,
           g.delete_requested, g.delete_time, g.intro,
           g.join_process_type, g.join_restrict_level
    FROM guild g
    WHERE g.id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguild_20150508(INTEGER);
-- +goose StatementEnd
