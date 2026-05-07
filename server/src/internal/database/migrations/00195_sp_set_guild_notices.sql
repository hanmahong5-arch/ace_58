-- AionCore 5.8 — Sprint 1.1a batch 12 port: aion_SetGuildNotices.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildNotices.sql
-- Original (T-SQL):
--   UPDATE guild
--      SET noticetime1=@..., notice1=@..., ... noticetime7=@..., notice7=@...
--    WHERE id = @nGuildId
--
-- Translation notes:
--   * NCSoft's legion has a 7-slot announcement board (`/legion notice`).
--     The client always writes ALL 7 slots in one shot — there is no
--     per-slot SP. Hence one massive UPDATE.
--   * `notice<N>` is `nvarchar(256)` in T-SQL → PG TEXT (no enforced limit;
--     the gateway truncates client-side at 256 wide chars, matching the
--     legion-notice protocol packet shape).
--   * `noticetime<N>` is INT (epoch seconds).
--   * Schema extension: 14 new columns. Defaults are 0 / '' so existing
--     rows come up clean after migration.
--   * NO existence guard on _guild_id (bug-for-bug). UPDATE on a deleted
--     guild silently no-ops (0 rows affected).
--   * Returns rows-affected so callers can detect the missing-guild case.
--
-- Used by:
--   scripts/handlers/cm_legion_notice_set.lua  -- on /legion notice
--   scripts/lib/guild.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- guild — extend with the 7-slot notice board (text + epoch each).
-- NCSoft column names are notice1..7 / noticetime1..7 (no underscore);
-- we mirror exactly so future GetGuildNotices port is a 1:1 SELECT.
-- ====================================================================
ALTER TABLE guild
    ADD COLUMN IF NOT EXISTS noticetime1 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice1     TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS noticetime2 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice2     TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS noticetime3 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice3     TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS noticetime4 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice4     TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS noticetime5 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice5     TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS noticetime6 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice6     TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS noticetime7 INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS notice7     TEXT    NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildnotices(
    INTEGER,
    INTEGER, TEXT, INTEGER, TEXT, INTEGER, TEXT,
    INTEGER, TEXT, INTEGER, TEXT, INTEGER, TEXT, INTEGER, TEXT
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildnotices(
    _guild_id      INTEGER,
    _notice_time1  INTEGER, _notice1 TEXT,
    _notice_time2  INTEGER, _notice2 TEXT,
    _notice_time3  INTEGER, _notice3 TEXT,
    _notice_time4  INTEGER, _notice4 TEXT,
    _notice_time5  INTEGER, _notice5 TEXT,
    _notice_time6  INTEGER, _notice6 TEXT,
    _notice_time7  INTEGER, _notice7 TEXT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE guild
       SET noticetime1 = _notice_time1, notice1 = _notice1,
           noticetime2 = _notice_time2, notice2 = _notice2,
           noticetime3 = _notice_time3, notice3 = _notice3,
           noticetime4 = _notice_time4, notice4 = _notice4,
           noticetime5 = _notice_time5, notice5 = _notice5,
           noticetime6 = _notice_time6, notice6 = _notice6,
           noticetime7 = _notice_time7, notice7 = _notice7
     WHERE id = _guild_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildnotices(
    INTEGER,
    INTEGER, TEXT, INTEGER, TEXT, INTEGER, TEXT,
    INTEGER, TEXT, INTEGER, TEXT, INTEGER, TEXT, INTEGER, TEXT
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE guild
    DROP COLUMN IF EXISTS notice7,
    DROP COLUMN IF EXISTS noticetime7,
    DROP COLUMN IF EXISTS notice6,
    DROP COLUMN IF EXISTS noticetime6,
    DROP COLUMN IF EXISTS notice5,
    DROP COLUMN IF EXISTS noticetime5,
    DROP COLUMN IF EXISTS notice4,
    DROP COLUMN IF EXISTS noticetime4,
    DROP COLUMN IF EXISTS notice3,
    DROP COLUMN IF EXISTS noticetime3,
    DROP COLUMN IF EXISTS notice2,
    DROP COLUMN IF EXISTS noticetime2,
    DROP COLUMN IF EXISTS notice1,
    DROP COLUMN IF EXISTS noticetime1;
-- +goose StatementEnd
