-- AionCore 5.8 — Sprint 1.1a batch 26 port: aion_SetInfinitySeasonRecord
-- (upsert per-character Infinity Shard PvP arena season reward state).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInfinitySeasonRecord.sql
-- Original (T-SQL):
--   begin tran
--   update user_extra_info set prevSeasonReward = @prev,
--                              currentSeasonReward = @current
--    where char_id = @charid
--   if @@ROWCOUNT = 0
--     insert into user_extra_info
--       (char_id, use_bot_channel, account_id, vip_icon,
--        prevSeasonReward, currentSeasonReward)
--     values (@charid, 0, 0, 0, @prev, @current)
--   commit tran
--
-- Schema:
--   `user_extra_info` was introduced by 00264 (sister GetInfinitySeasonRecord).
--
-- Translation notes:
--   * NCSoft uses the canonical "update-then-insert" upsert pattern wrapped
--     in a transaction. Every PG plpgsql function runs inside the calling
--     transaction by default, so we don't need explicit BEGIN/COMMIT
--     (it would even raise — plpgsql cannot manage outer transactions).
--     Pinned: the upsert semantics are byte-equal to NCSoft.
--   * We use ON CONFLICT DO UPDATE rather than IF FOUND for a single
--     atomic statement. This is *strictly tighter* than NCSoft's two-step
--     pattern (which had a thin race window between UPDATE and INSERT
--     under SQL Server's default isolation level — the BEGIN TRAN does
--     not eliminate the race without UPDLOCK hints). PG's ON CONFLICT
--     guarantees atomicity. Bug-for-bug compatibility preserved on the
--     observable surface (final row state).
--   * Insert column list pinned exactly as NCSoft writes it:
--       (char_id, use_bot_channel, account_id, vip_icon,
--        prevSeasonReward, currentSeasonReward)
--     Defaults: use_bot_channel=0, account_id=0, vip_icon=0. Pinned.
--   * RETURNS VOID — caller cannot inspect upsert outcome.
--
-- Bug-for-bug:
--   * Insert path hard-codes account_id=0. NCSoft used 0 as "unknown
--     account" sentinel even though account_id is INT NULL in the schema.
--     Pinned (a NULL would be more semantically correct but NCSoft chose 0).
--   * Insert path hard-codes use_bot_channel=0 and vip_icon=0 even though
--     both have other writers. Pinned (race: if InfinitySeasonRecord is
--     the FIRST writer for a char, we pin those columns to 0; subsequent
--     writers overwrite normally).
--   * use_bot_channel_update_date is NOT in the insert column list — it
--     stays NULL. Pinned.
--
-- Used by:
--   scripts/handlers/cm_infinity_season_settle.lua  -- end-of-season payout
--   scripts/lib/infinity_arena.lua                   -- Q3 entropy hook

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinfinityseasonrecord(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : character to upsert
-- _prev    : previous season reward count (becomes "prevSeasonReward")
-- _current : current season reward count  (becomes "currentSeasonReward")
-- Inserted defaults match NCSoft: use_bot_channel=0, account_id=0, vip_icon=0.
CREATE OR REPLACE FUNCTION aion_setinfinityseasonrecord(
    _char_id INTEGER,
    _prev    INTEGER,
    _current INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Single-statement atomic upsert. PG's ON CONFLICT collapses NCSoft's
    -- two-step UPDATE-then-INSERT into one race-free operation while
    -- preserving the final-row-state contract.
    INSERT INTO user_extra_info
        (char_id, use_bot_channel, account_id, vip_icon,
         "prevSeasonReward", "currentSeasonReward")
    VALUES (_char_id, 0, 0, 0, _prev, _current)
    ON CONFLICT (char_id) DO UPDATE
       SET "prevSeasonReward"    = EXCLUDED."prevSeasonReward",
           "currentSeasonReward" = EXCLUDED."currentSeasonReward";
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinfinityseasonrecord(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
