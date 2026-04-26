-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_PutGuild_20100916.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutGuild_20100916.sql
-- Returns:
--   >0  — new guild.id
--  -1  — name already exists
--  -2  — name is forbidden
--   0  — INSERT failed (preserved for parity, hard to trigger in PG)
--
-- Forbidden-name checks short-circuit before INSERT. The original SP also
-- references a "notice1..notice7" set of TEXT columns we haven't scaffolded
-- (legion MOTD, separate Round 6 SP); we INSERT those as default '' via
-- the column DEFAULT.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putguild_20100916(TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- guild table predates this round; ensure the IDENTITY behaviour matches
-- T-SQL @@IDENTITY by adding a sequence + default if missing. The original
-- 00002 scaffold defined guild.id as plain INTEGER PK; we attach a sequence
-- here for callers that omit the id (PutGuild does).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_sequences WHERE sequencename = 'guild_id_seq') THEN
        CREATE SEQUENCE guild_id_seq START 1;
        EXECUTE 'ALTER TABLE guild ALTER COLUMN id SET DEFAULT nextval(''guild_id_seq'')';
        EXECUTE 'ALTER SEQUENCE guild_id_seq OWNED BY guild.id';
    END IF;
END$$;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putguild_20100916(
    _name              TEXT,
    _master_id         INTEGER,
    _race              INTEGER,
    _submaster_right   INTEGER,
    _officer_right     INTEGER,
    _member_right      INTEGER,
    _newbie_right      INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    _new_id INTEGER;
BEGIN
    -- Duplicate name?
    IF EXISTS (SELECT 1 FROM guild WHERE name = _name) THEN
        RETURN -1;
    END IF;

    -- Forbidden word — exact, common bucket
    IF EXISTS (
        SELECT 1 FROM forbidden_word
         WHERE forbidden_word = _name AND is_like = 0 AND status = 0
           AND forbidden_type = 0
    ) THEN RETURN -2; END IF;

    -- Forbidden word — exact, guild bucket (excluding rename-cooldown reason=5)
    IF EXISTS (
        SELECT 1 FROM forbidden_word
         WHERE forbidden_word = _name AND is_like = 0 AND status = 0
           AND forbidden_type = 2 AND forbidden_reason <> 5
    ) THEN RETURN -2; END IF;

    -- Guild rename-cooldown — 366-day window
    IF EXISTS (
        SELECT 1 FROM forbidden_word
         WHERE forbidden_word = _name AND is_like = 0 AND status = 0
           AND forbidden_type = 2 AND forbidden_reason = 5
           AND (NOW()::DATE - regdate::DATE) < 366
    ) THEN RETURN -2; END IF;

    -- Substring forbidden
    IF EXISTS (
        SELECT 1 FROM forbidden_word
         WHERE _name LIKE '%' || forbidden_word || '%'
           AND forbidden_word <> ''
           AND is_like = 1 AND status = 0
           AND forbidden_type IN (0, 2)
    ) THEN RETURN -2; END IF;

    INSERT INTO guild (
        name, race, master_id, level, rank,
        submaster_right, officer_right, member_right, newbie_right,
        point, fund, delete_requested, delete_time, intro
    ) VALUES (
        _name, _race, _master_id, 1, 0,
        _submaster_right, _officer_right, _member_right, _newbie_right,
        0, 0, 0, 0, ''
    )
    RETURNING id INTO _new_id;

    RETURN _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putguild_20100916(TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
