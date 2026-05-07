-- AionCore 5.8 — Sprint 1.1a batch 26 port: aion_GetInfinitySeasonRecord
-- (read per-character "Infinity Shard" PvP arena season reward state).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetInfinitySeasonRecord.sql
-- Original (T-SQL):
--   select ISNULL(prevSeasonReward, 0), ISNULL(currentSeasonReward, 0)
--   from user_extra_info where char_id = @charid
--
-- Domain (NEW — not previously touched):
--   `user_extra_info` is the side-table NCSoft uses to stash per-character
--   bookkeeping that doesn't belong on `users`. The two columns this SP
--   reads — prevSeasonReward / currentSeasonReward — track Infinity Shard
--   PvP arena season payout state. NULL means "never participated"; the
--   ISNULL coalesces both to 0 so the caller never sees NULL.
--
-- Schema (from NCSoft AionWorldLive._schema/tables.sql lines 1512-1520):
--   CREATE TABLE user_extra_info (
--       char_id                     int      NOT NULL,
--       use_bot_channel             tinyint  NOT NULL,
--       use_bot_channel_update_date datetime NULL,
--       account_id                  int      NULL,
--       vip_icon                    smallint NULL DEFAULT 0,
--       prevSeasonReward            int      NULL,
--       currentSeasonReward         int      NULL
--   );
--
--   * No PK in NCSoft (they index via clustered index on char_id elsewhere).
--     We add PRIMARY KEY (char_id) — strict tightening, live data unique.
--   * Column casing pinned: "prevSeasonReward" / "currentSeasonReward" are
--     PascalCase in NCSoft. We preserve via double-quoted identifiers
--     (PostgreSQL folds bare identifiers to lowercase, would break the
--     column reference in the SP body).
--   * `vip_icon` DEFAULT 0 mirrored — sister SP 00265 inserts a literal 0
--     into vip_icon explicitly so the default is documentation-only here.
--
-- Translation notes:
--   * SETOF return matches "select two scalars" — pgx scans 1 row of 2 ints.
--   * ISNULL(x, 0) → COALESCE(x, 0) (PG idiom).
--   * Char absent from table → 0 rows (NCSoft also returns 0 rows; the
--     ISNULL only protects against the NULL columns of an EXISTING row).
--     Pinned: caller must distinguish "no row" vs "(0, 0) row".
--
-- Bug-for-bug:
--   * Returns 2 INTEGER columns. NCSoft column 1 = prev, column 2 = current.
--     Pinned ordering.
--   * Char_id with NULL prev and non-NULL current returns (0, current).
--     Pinned (ISNULL applied per-column independently).
--   * No char_id existence check: missing row → 0 result rows, not (0, 0).
--     Pinned (caller's contract, not the SP's job to synthesise defaults).
--
-- Used by:
--   scripts/handlers/cm_infinity_season_query.lua  -- reward UI on login
--   scripts/lib/infinity_arena.lua                  -- Q3 entropy hook

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_extra_info — first introduction. Per-character side-table for
-- non-core bookkeeping (bot detection, VIP icon, PvP arena season reward).
-- PK on char_id added (NCSoft did not have one, but live data is unique).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_extra_info (
    char_id                       INTEGER  NOT NULL,
    use_bot_channel               SMALLINT NOT NULL DEFAULT 0,
    use_bot_channel_update_date   TIMESTAMP NULL,
    account_id                    INTEGER  NULL,
    vip_icon                      SMALLINT NULL DEFAULT 0,
    "prevSeasonReward"            INTEGER  NULL,
    "currentSeasonReward"         INTEGER  NULL,
    PRIMARY KEY (char_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinfinityseasonrecord(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : character whose Infinity Shard season state we want
-- Returns at most 1 row; missing char → 0 rows.
-- prev / current default to 0 only when the row exists with NULL columns.
CREATE OR REPLACE FUNCTION aion_getinfinityseasonrecord(_char_id INTEGER)
RETURNS TABLE (
    prev    INTEGER,
    current INTEGER
)
LANGUAGE sql STABLE AS $$
    SELECT COALESCE("prevSeasonReward", 0),
           COALESCE("currentSeasonReward", 0)
      FROM user_extra_info
     WHERE char_id = _char_id;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinfinityseasonrecord(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_extra_info;
-- +goose StatementEnd
