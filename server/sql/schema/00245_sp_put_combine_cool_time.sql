-- AionCore 5.8 — Sprint 1.1a batch 22 port: aion_PutCombineCoolTime
-- (write-side companion of 00167 GetCombineCoolTimeList — per-row upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutCombineCoolTime.sql
-- Original (T-SQL):
--   if exists (select char_id from user_combine_cooltime(UPDLOCK)
--              where char_id = @char_id and cooltime_id = @cooltime_id)
--       update user_combine_cooltime
--          set expire_cooltime = @expire_cooltime
--        where char_id = @char_id and cooltime_id = @cooltime_id
--   else
--       insert user_combine_cooltime(char_id, cooltime_id, expire_cooltime)
--       values (@char_id, @cooltime_id, @expire_cooltime)
--
-- Schema:
--   user_combine_cooltime is per-row keyed (char_id, cooltime_id) — that is
--   the **inverse shape** of user_item_cooltime (single-row blob). The PG
--   table was created in 00167 (GetCombineCoolTimeList) including its
--   composite PK; we do NOT re-create it here.
--
-- Translation notes:
--   * EXISTS-UPDATE-or-INSERT under UPDLOCK → INSERT … ON CONFLICT
--     (char_id, cooltime_id) DO UPDATE on the composite PK. Atomic write,
--     no UPDLOCK gymnastics needed under PG MVCC.
--   * Type widths verified against 00167 schema:
--       cooltime_id     INTEGER → matches NCSoft `int`
--       expire_cooltime BIGINT  → matches NCSoft `bigint` (epoch ms)
--   * VOID return: NCSoft contract has no rows-affected. Lua callers must
--     not branch on this SP's return value (none).
--
-- Bug-for-bug:
--   * Setting expire_cooltime to a past timestamp does NOT auto-delete the
--     row — NCSoft contract is "consumer filters by `now() < expire_ms`".
--     Pinned (consistent with how 00167 returns ALL rows without filter).
--   * No FK on char_id. Orphan-tolerant.
--   * No clamp on expire_cooltime. Negative values are accepted (NCSoft
--     uses 0 / negative as "expired-and-recyclable" sentinel). Pinned.
--
-- Used by:
--   scripts/handlers/cm_combine_complete.lua  -- recipe-class throttle write
--   scripts/lib/combine_cooltime.lua          -- shared mutation helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcombinecooltime(INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id          : owning char_id (composite PK part 1)
-- _cooltime_id      : combine-class catalog id (composite PK part 2; combine_cool_time.xml)
-- _expire_cooltime  : unix epoch ms when this cooldown ends (negative ok per NCSoft)
CREATE OR REPLACE FUNCTION aion_putcombinecooltime(
    _char_id         INTEGER,
    _cooltime_id     INTEGER,
    _expire_cooltime BIGINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_combine_cooltime (char_id, cooltime_id, expire_cooltime)
    VALUES (_char_id, _cooltime_id, _expire_cooltime)
    ON CONFLICT (char_id, cooltime_id) DO UPDATE SET
        expire_cooltime = EXCLUDED.expire_cooltime;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcombinecooltime(INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd
