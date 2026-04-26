-- AionCore 5.8 — Sprint 1.1a scaffold for ported NCSoft SPs.
--
-- This migration deploys the minimum schema surface required for the first
-- five hand-fixed T-SQL → PG ports (00003–00007). It is NOT the full
-- AionWorldLive schema — only the columns the ported SPs actually touch.
-- Round 5+ migrations will extend these tables as more SPs come online.
--
-- Tables:
--   user_data  — character row (char_id PK, guild_id, delete_date, …)
--   guild      — legion row (id PK, name, race, level, …)
--
-- Helper functions:
--   GetUnixtimeWithUTCAdjust(ts, tz_offset_hours) — NCSoft's epoch-int helper.
--     Mirrors `dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)` semantics:
--     returns the integer Unix epoch seconds of the input timestamp shifted
--     by the given hour offset. Used by aion_SetCharDeleteTime,
--     aion_SetGuildMember, aion_CheckValidCharName, etc.

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS guild (
    id                 INTEGER PRIMARY KEY,
    name               TEXT        NOT NULL,
    race               INTEGER     NOT NULL DEFAULT 0,
    master_id          INTEGER     NOT NULL DEFAULT 0,
    level              INTEGER     NOT NULL DEFAULT 1,
    rank               INTEGER     NOT NULL DEFAULT 0,
    submaster_right    INTEGER     NOT NULL DEFAULT 0,
    officer_right      INTEGER     NOT NULL DEFAULT 0,
    member_right       INTEGER     NOT NULL DEFAULT 0,
    newbie_right       INTEGER     NOT NULL DEFAULT 0,
    point              BIGINT      NOT NULL DEFAULT 0,
    fund               BIGINT      NOT NULL DEFAULT 0,
    this_week_tld      INTEGER     NOT NULL DEFAULT 0,
    last_week_tld      INTEGER     NOT NULL DEFAULT 0,
    tld_update_time    INTEGER     NOT NULL DEFAULT 0,
    delete_requested   INTEGER     NOT NULL DEFAULT 0,
    delete_time        INTEGER     NOT NULL DEFAULT 0,
    intro              TEXT        NOT NULL DEFAULT '',
    join_process_type  INTEGER     NOT NULL DEFAULT 0,
    join_restrict_level INTEGER    NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_data (
    char_id            INTEGER PRIMARY KEY,
    name               TEXT        NOT NULL DEFAULT '',
    account_id         INTEGER     NOT NULL DEFAULT 0,
    guild_id           INTEGER     NOT NULL DEFAULT 0,
    guild_update_date  TIMESTAMPTZ,
    delete_date        INTEGER     NOT NULL DEFAULT 0,
    change_info_time   BIGINT      NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_data_guild ON user_data(guild_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- NCSoft helper: convert a timestamp into Unix-epoch seconds with optional
-- hour offset. The original T-SQL UDF returns BIGINT; we mirror that exactly.
CREATE OR REPLACE FUNCTION GetUnixtimeWithUTCAdjust(
    ts          TIMESTAMPTZ,
    hour_offset INTEGER
) RETURNS BIGINT
LANGUAGE SQL IMMUTABLE AS $$
    SELECT EXTRACT(EPOCH FROM ts)::BIGINT + (hour_offset::BIGINT * 3600);
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS GetUnixtimeWithUTCAdjust(TIMESTAMPTZ, INTEGER);
DROP TABLE IF EXISTS user_data;
DROP TABLE IF EXISTS guild;
-- +goose StatementEnd
