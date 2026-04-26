-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) PvE scaffold round 4.
--
-- Adds the schema surface required by the Round 7 SP batch:
--   Legion-Dominion (6 SPs):
--     legion_dominion_rankings   — territorial siege scoreboard.
--   Abyss (7 SPs):
--     abyss_ranking              — per-server PvP/GP ranking snapshot.
--     abyss_region_ranking       — top-50 guild abyss leaderboard.
--     abyss_op_point             — per-race owned-objective point cache.
--     abyss_user_owner           — per-territory owner contributor list (read-only here).
--     user_gp_data               — Glory Point bookkeeping (joined from OrderingAbyssRanking).
--   Auction (6 SPs):
--     user_auction               — housing auction listing.
--     user_auctionfilter         — per-type goods filter (block-list).
--     user_betting               — per-character active bet record.
--
-- guild table additions: emblem_img_version, emblem_bgcolor, old_rank,
-- point_max_time, cnt — referenced by aion_LoadLegionDominion* and
-- aion_SetAbyssGuildRank.

-- +goose Up

-- +goose StatementBegin
-- ====================================================================
-- guild — extra columns referenced by abyss / dominion SPs.
-- ====================================================================
ALTER TABLE guild
    ADD COLUMN IF NOT EXISTS emblem_img_version SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS emblem_bgcolor     INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS old_rank           INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS point_max_time     BIGINT   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cnt                INTEGER  NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- legion_dominion_rankings — append-only score history per guild/territory.
-- take_over_processed_time = 0 means "current cycle (in-flight)".
-- ====================================================================
CREATE TABLE IF NOT EXISTS legion_dominion_rankings (
    legion_id                 INTEGER  NOT NULL DEFAULT 0,
    dominion_id               INTEGER  NOT NULL DEFAULT 0,
    score                     INTEGER  NOT NULL DEFAULT 0,
    played_time_in_sec        INTEGER  NOT NULL DEFAULT 0,
    game_end_time             BIGINT   NOT NULL DEFAULT 0,
    take_over_processed_time  BIGINT   NOT NULL DEFAULT 0,
    server_id                 INTEGER  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_ldr_lookup
    ON legion_dominion_rankings(server_id, dominion_id, take_over_processed_time);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_ldr_legion
    ON legion_dominion_rankings(legion_id, dominion_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- abyss_ranking — recomputed periodically; one snapshot per update_time.
-- ====================================================================
CREATE TABLE IF NOT EXISTS abyss_ranking (
    abyss_ranking      INTEGER       NOT NULL DEFAULT 0,
    server_id          INTEGER       NOT NULL DEFAULT 0,
    update_time        BIGINT        NOT NULL DEFAULT 0,
    char_id            INTEGER       NOT NULL DEFAULT 0,
    abyss_point        BIGINT        NOT NULL DEFAULT 0,
    race               SMALLINT      NOT NULL DEFAULT 0,
    class              SMALLINT      NOT NULL DEFAULT 0,
    lev                INTEGER       NOT NULL DEFAULT 0,
    guild_id           INTEGER       NOT NULL DEFAULT 0,
    rank               INTEGER       NOT NULL DEFAULT 0,
    old_ranking        INTEGER       NOT NULL DEFAULT 0,
    gp                 BIGINT        NOT NULL DEFAULT 0,
    rank_updatedate    TIMESTAMPTZ
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_abyss_ranking_lookup
    ON abyss_ranking(server_id, race, update_time);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_abyss_ranking_char
    ON abyss_ranking(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- abyss_region_ranking — top-50 guild snapshot, recomputed by SetAbyssGuildRank.
-- ====================================================================
CREATE TABLE IF NOT EXISTS abyss_region_ranking (
    rank        INTEGER     NOT NULL,
    old_rank    INTEGER     NOT NULL DEFAULT 0,
    id          INTEGER     NOT NULL,
    race        SMALLINT    NOT NULL,
    level       INTEGER     NOT NULL DEFAULT 1,
    cnt         INTEGER     NOT NULL DEFAULT 0,
    point       BIGINT      NOT NULL DEFAULT 0,
    name        TEXT        NOT NULL DEFAULT '',
    updatetime  BIGINT      NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- abyss_op_point — per-race ownership-point cache; one row per race.
-- ====================================================================
CREATE TABLE IF NOT EXISTS abyss_op_point (
    race                SMALLINT  PRIMARY KEY,
    quest               INTEGER   NOT NULL DEFAULT 0,
    fortress            INTEGER   NOT NULL DEFAULT 0,
    artifact            INTEGER   NOT NULL DEFAULT 0,
    basecamp            INTEGER   NOT NULL DEFAULT 0,
    op_object           INTEGER   NOT NULL DEFAULT 0,
    raid_object         INTEGER   NOT NULL DEFAULT 0,
    ownership_object    INTEGER   NOT NULL DEFAULT 0,
    next_reset_time     INTEGER   NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- abyss_user_owner — per-abyss-territory owner contributor list.
-- (Read by GetAbyssUserOwnerInfo; not mutated by Round 7 SPs.)
-- ====================================================================
CREATE TABLE IF NOT EXISTS abyss_user_owner (
    abyss_id             INTEGER  NOT NULL,
    update_time          INTEGER  NOT NULL,
    owner_char_id        INTEGER  NOT NULL DEFAULT 0,
    owner_server_id      INTEGER  NOT NULL DEFAULT 0,
    owner_share_amount   BIGINT   NOT NULL DEFAULT 0,
    owner_rank           INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (abyss_id, update_time, owner_char_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_gp_data — per-char glory-point bookkeeping (joined into OrderingAbyssRanking).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_gp_data (
    char_id             INTEGER PRIMARY KEY,
    glory_point         BIGINT  NOT NULL DEFAULT 0,
    ownership_bonus_gp  BIGINT  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_auction — housing auction listing (auction = housing only in 5.8).
-- type   : auction class (estate/villa/manor/...)
-- state  : 0 in-progress, 1 ready-to-settle, 2+ settled/cancelled
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_auction (
    id          BIGSERIAL    PRIMARY KEY,
    type        INTEGER      NOT NULL,
    race        SMALLINT     NOT NULL,
    goodsID     INTEGER      NOT NULL,
    sellerID    INTEGER      NOT NULL DEFAULT 0,
    sellerName  TEXT         NOT NULL DEFAULT '',
    InitQina    BIGINT       NOT NULL DEFAULT 0,
    qina        BIGINT       NOT NULL DEFAULT 0,
    stepqina    BIGINT       NOT NULL DEFAULT 0,
    state       SMALLINT     NOT NULL DEFAULT 0,
    buyerID     INTEGER      NOT NULL DEFAULT 0,
    buyerName   TEXT         NOT NULL DEFAULT '',
    lastupdate  INTEGER      NOT NULL DEFAULT 0,
    createtime  INTEGER      NOT NULL DEFAULT 0,
    betCount    INTEGER      NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_auction_lookup
    ON user_auction(type, race, state);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_auction_goods
    ON user_auction(goodsID, state);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_auctionfilter — block-listed goods (per type bucket).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_auctionfilter (
    filterid  BIGSERIAL PRIMARY KEY,
    type      INTEGER NOT NULL,
    goodsID   INTEGER NOT NULL,
    UNIQUE (type, goodsID)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- user_betting — at-most-one active bet per character (PK is char_id).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_betting (
    ownerid    INTEGER PRIMARY KEY,
    auctionid  BIGINT  NOT NULL,
    qina       BIGINT  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose Down

-- +goose StatementBegin
DROP TABLE IF EXISTS user_betting;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_auctionfilter;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_auction_goods;
DROP INDEX IF EXISTS idx_user_auction_lookup;
DROP TABLE IF EXISTS user_auction;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_gp_data;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS abyss_user_owner;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS abyss_op_point;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS abyss_region_ranking;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_abyss_ranking_char;
DROP INDEX IF EXISTS idx_abyss_ranking_lookup;
DROP TABLE IF EXISTS abyss_ranking;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_ldr_legion;
DROP INDEX IF EXISTS idx_ldr_lookup;
DROP TABLE IF EXISTS legion_dominion_rankings;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE guild
    DROP COLUMN IF EXISTS cnt,
    DROP COLUMN IF EXISTS point_max_time,
    DROP COLUMN IF EXISTS old_rank,
    DROP COLUMN IF EXISTS emblem_bgcolor,
    DROP COLUMN IF EXISTS emblem_img_version;
-- +goose StatementEnd
