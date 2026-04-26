-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) PvE scaffold round 5.
--
-- Adds the schema surface required by the Round 8 social/housing SP batch:
--   Housing (6 SPs):
--     house_instant       — current state of each player's house cell.
--     houseobject         — placed furniture/decor objects (1 row per item).
--   Pet (5 SPs):
--     user_pet            — adopted pets (BIGSERIAL id, char_id FK).
--   Faction friendship (3 SPs):
--     user_faction_friendship — per-character per-faction reputation.
--   Block list (4 SPs):
--     user_block          — ignore list (per-character).
--   Sticker / app installation (2 SPs):
--     user_app_installation   — character can-make-sticker flag + login_time.
--
-- One new T-SQL helper UDF is needed:
--   GetUtcAdjustSecWithUTC_Local(utc, local) → BIGINT
--     Returns the seconds offset between server-local and UTC clocks. NCSoft
--     uses GetDate()/GetUTCDate() — we receive both as TIMESTAMPTZ args.

-- +goose Up

-- +goose StatementBegin
-- ====================================================================
-- house_instant — exactly 1 row per house cell (id == owner char_id).
-- ====================================================================
CREATE TABLE IF NOT EXISTS house_instant (
    id            INTEGER  PRIMARY KEY,
    state         SMALLINT NOT NULL DEFAULT 0,
    permission    SMALLINT NOT NULL DEFAULT 0,
    inwall        INTEGER  NOT NULL DEFAULT 0,
    infloor       INTEGER  NOT NULL DEFAULT 0,
    update_time   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_time  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- houseobject — every placed object (furniture/decor/utility).
-- BIGSERIAL id mirrors NCSoft IDENTITY(1,1).
--
-- owner_type = 1 → personal house (most common for 5.8 players).
-- state = 0 → soft-deleted (excluded by GetHouseObjectInstant).
-- ====================================================================
CREATE TABLE IF NOT EXISTS houseobject (
    id                 BIGSERIAL PRIMARY KEY,
    object_nameid      INTEGER  NOT NULL,
    object_type        SMALLINT NOT NULL DEFAULT 0,
    owner_id           INTEGER  NOT NULL DEFAULT 0,
    owner_type         SMALLINT NOT NULL DEFAULT 0,
    state              SMALLINT NOT NULL DEFAULT 1,
    expired_time       INTEGER  NOT NULL DEFAULT 0,
    general_use_count  INTEGER  NOT NULL DEFAULT 0,
    world              INTEGER  NOT NULL DEFAULT 0,
    xlocation          REAL     NOT NULL DEFAULT 0,
    ylocation          REAL     NOT NULL DEFAULT 0,
    zlocation          REAL     NOT NULL DEFAULT 0,
    dir                SMALLINT NOT NULL DEFAULT 0,
    dye_info           INTEGER,
    expire_dye_time    INTEGER,
    update_time        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_time       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_houseobject_owner
    ON houseobject(owner_type, owner_id, state);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_pet — one row per pet a character has acquired. id BIGSERIAL.
--
-- function_data1/2 + 3 _ex* slots = packed binary attribute blocks
-- name_id is the catalogue id (matches client xml). slot_id 1..N
-- visual_data is bytea (T-SQL varbinary(100)).
-- change_info_time = unix-epoch BIGINT, set in SP via GetUnixtimeWithUTCAdjust.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_pet (
    id                    BIGSERIAL PRIMARY KEY,
    char_id               INTEGER NOT NULL,
    name_id               INTEGER NOT NULL,
    slot_id               SMALLINT NOT NULL DEFAULT 0,
    name                  TEXT     NOT NULL DEFAULT '',
    function_data1        BIGINT   NOT NULL DEFAULT 0,
    function_data1_ex1    BIGINT   NOT NULL DEFAULT 0,
    function_data1_ex2    BIGINT   NOT NULL DEFAULT 0,
    function_data1_ex3    BIGINT   NOT NULL DEFAULT 0,
    function_data2        BIGINT   NOT NULL DEFAULT 0,
    function_data2_ex1    BIGINT   NOT NULL DEFAULT 0,
    function_data2_ex2    BIGINT   NOT NULL DEFAULT 0,
    function_data2_ex3    BIGINT   NOT NULL DEFAULT 0,
    visual_data_size      INTEGER  NOT NULL DEFAULT 0,
    visual_data           BYTEA,
    change_info_time      BIGINT   NOT NULL DEFAULT 0,
    expired_time          INTEGER  NOT NULL DEFAULT 0,
    create_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_pet_char ON user_pet(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_faction_friendship — per-character per-faction reputation row.
-- (factionquest_* columns referenced by GetFactionFriendshipList output.)
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_faction_friendship (
    char_id                          INTEGER  NOT NULL,
    faction_id                       SMALLINT NOT NULL,
    friendship                       INTEGER  NOT NULL DEFAULT 0,
    jointime                         INTEGER  NOT NULL DEFAULT 0,
    factionquest_curid               INTEGER  NOT NULL DEFAULT 0,
    factionquest_curstate            SMALLINT NOT NULL DEFAULT 0,
    factionquest_lastacquiredtime    INTEGER  NOT NULL DEFAULT 0,
    factionquest_lastfinishedtime    INTEGER  NOT NULL DEFAULT 0,
    factionquest_finishedcount       INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, faction_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_block — ignore list. (char_id, block_id) is the natural PK.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_block (
    char_id   INTEGER NOT NULL,
    block_id  INTEGER NOT NULL,
    comment   TEXT    NOT NULL DEFAULT '',
    PRIMARY KEY (char_id, block_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_app_installation — one row per character with their sticker app
-- entitlement and last-login bookkeeping.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_app_installation (
    char_id            INTEGER  PRIMARY KEY,
    can_make_sticker   SMALLINT NOT NULL DEFAULT 0,
    login_time         INTEGER  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- GetUtcAdjustSecWithUTC_Local — NCSoft helper. Returns BIGINT seconds
-- between local clock and UTC. We compute as EPOCH(local) - EPOCH(utc).
-- (Original T-SQL uses DATEDIFF(SECOND, utc, local).)
-- ====================================================================
CREATE OR REPLACE FUNCTION GetUtcAdjustSecWithUTC_Local(
    utc_ts   TIMESTAMPTZ,
    local_ts TIMESTAMPTZ
) RETURNS BIGINT
LANGUAGE SQL IMMUTABLE AS $$
    SELECT EXTRACT(EPOCH FROM local_ts)::BIGINT - EXTRACT(EPOCH FROM utc_ts)::BIGINT;
$$;
-- +goose StatementEnd

-- +goose Down

-- +goose StatementBegin
DROP FUNCTION IF EXISTS GetUtcAdjustSecWithUTC_Local(TIMESTAMPTZ, TIMESTAMPTZ);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_app_installation;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_block;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_faction_friendship;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_pet_char;
DROP TABLE IF EXISTS user_pet;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_houseobject_owner;
DROP TABLE IF EXISTS houseobject;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS house_instant;
-- +goose StatementEnd
