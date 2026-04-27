-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) PvE scaffold round 6.
--
-- Adds the schema surface required by the Round 9 instance/achievement SP batch:
--   instance              — extend with spawn_page + phase_data (originally created
--                           in 00008_pve_scaffold_round2 with only validity_time).
--   world_extcondition    — KV store keyed by (world_type, world_num, variable);
--                           used by Get/SetInstanceCondition + Get/SetWorldExtCondition.
--   user_instance_extracount — per-char per-map "extra Abyss-OP entries today" counter.
--   user_instance_achievement — per-char binary blob of finished objectives per
--                           (world_id, spawn_page, version). varbinary(100) → bytea.
--   user_monster_achievement — per-char counter+grade+reward_received per achieve_id.
--
-- All five tables follow snake_case + COALESCE-defaulted columns so subsequent
-- SP UPSERT bodies stay readable.

-- +goose Up

-- +goose StatementBegin
-- ====================================================================
-- instance — extend with spawn_page + phase_data so SetInstance/GetInstance
-- can persist the full PERSISTENT_INSTANCE record.
-- ====================================================================
ALTER TABLE instance
    ADD COLUMN IF NOT EXISTS spawn_page  INTEGER       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS phase_data  VARCHAR(1024) NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- world_extcondition — generic 4-tuple (world_type, world_num, variable, value).
--   world_type: 0 = persistent world, 1 = instance dungeon
--   world_num : world_id (or instance_id when type=1)
--   variable  : free-text key (NCSoft uses CRC32 hash too, kept for parity)
-- BIGSERIAL id matches the T-SQL `id INT IDENTITY` column, used by SetXxx
-- when there are duplicate (variable_hash) rows that must be disambiguated
-- by the human-readable `variable` column.
-- ====================================================================
CREATE TABLE IF NOT EXISTS world_extcondition (
    id              BIGSERIAL    PRIMARY KEY,
    world_type      SMALLINT     NOT NULL DEFAULT 0,
    world_num       INTEGER      NOT NULL DEFAULT 0,
    variable        VARCHAR(256) NOT NULL DEFAULT '',
    variable_hash   INTEGER      NOT NULL DEFAULT 0,
    value           INTEGER      NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
-- Hot-path index: every SP query hits (world_type, world_num, variable_hash).
CREATE INDEX IF NOT EXISTS idx_world_extcondition_lookup
    ON world_extcondition(world_type, world_num, variable_hash);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_instance_extracount — per (char, map) counter of "extra Abyss-OP
-- entries used today". Reset is driven by next_reset_time (BIGINT epoch ms).
-- T-SQL declared @extraCount as TINYINT — PG SMALLINT keeps the same range.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_instance_extracount (
    char_id              INTEGER  NOT NULL,
    map_number           INTEGER  NOT NULL,
    extra_count_abyssop  SMALLINT NOT NULL DEFAULT 0,
    next_reset_time      BIGINT   NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, map_number)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_instance_achievement — varbinary(100) blob of completed objectives
-- per (char, world, spawn_page, version). Composite PK = upsert key.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_instance_achievement (
    id          BIGSERIAL PRIMARY KEY,
    char_id     INTEGER NOT NULL,
    world_id    INTEGER NOT NULL,
    spawn_page  INTEGER NOT NULL DEFAULT 0,
    version     INTEGER NOT NULL DEFAULT 0,
    data        BYTEA   NOT NULL DEFAULT '\x'::bytea,
    UNIQUE (char_id, world_id, spawn_page, version)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_instance_achievement_char
    ON user_instance_achievement(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_monster_achievement — per (char, achieve_id) counter row.
-- reward_received is monotonic: each grade reward bumps it +1 atomically
-- (see SetMonsterAchievementRewardReceived's WHERE reward_received = N-1).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_monster_achievement (
    char_id          INTEGER  NOT NULL,
    achieve_id       INTEGER  NOT NULL,
    achieved_count   INTEGER  NOT NULL DEFAULT 0,
    achieved_grade   SMALLINT NOT NULL DEFAULT 0,
    reward_received  SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, achieve_id)
);
-- +goose StatementEnd

-- +goose Down

-- +goose StatementBegin
DROP TABLE IF EXISTS user_monster_achievement;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_instance_achievement;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_instance_extracount;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS world_extcondition;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE instance
    DROP COLUMN IF EXISTS phase_data,
    DROP COLUMN IF EXISTS spawn_page;
-- +goose StatementEnd
