-- AionCore 5.8 — Sprint 1.1a batch 23 port: aion_SetCharEXPS_RewardNum
-- (per-NPC-kill increment of the EXPS counter — paired with 00252).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharEXPS_RewardNum.sql
-- Original (T-SQL):
--   UPDATE user_data_ext
--   SET exps_npckill_reward_num = exps_npckill_reward_num + 1
--   where char_id = @charId
--
-- Domain (`char_exps_reward`, sister to 00252):
--   See 00252 header for the full EXPS rationale. This SP is the kill-tick
--   half — invoked once per NPC kill event to bump the per-character
--   counter that decides EXPS payout / cap.
--
-- Schema:
--   user_data_ext columns `exps_login_reward_time` / `exps_npckill_reward_num`
--   are added by 00252 (idempotent ALTER ADD COLUMN IF NOT EXISTS). Goose
--   guarantees 00252 runs before 00253 (numeric ordering), so by the time
--   this SP is created the columns are guaranteed present.
--
-- Translation notes:
--   * Single-statement UPDATE; no UPDLOCK in NCSoft (a stable single-row
--     update on PK is atomic on both engines).
--   * Silent no-op on missing row. Pinned: NCSoft does NOT auto-create
--     a user_data_ext row on the kill path — only the login-time SP
--     (00252) does. If a kill arrives before the first login (impossible
--     in practice but defensible), the increment is silently lost.
--     Pinned exactly as NCSoft.
--   * RETURNS INTEGER (rows-affected: 0 or 1). Strict widening of the
--     NCSoft VOID contract — same convention as 00251.
--
-- Bug-for-bug:
--   * No upper-bound clamp on the counter. NCSoft EXPS-cap logic lives
--     CLIENT-side / Lua-side; the SP is a raw incrementer. Pinned.
--   * Integer overflow at 2^31-1 increments — caller must cap before
--     this SP to avoid PG `integer out of range` ERROR. Pinned: NCSoft
--     hits the same wall (silently wraps in T-SQL — PG raises). This
--     is NOT a regression in practice (no one kills 2.1B NPCs / day).
--
-- Used by:
--   scripts/events/on_kill.lua            -- mob death event
--   scripts/lib/exps_reward.lua           -- shared EXPS helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharexps_rewardnum(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : owning char_id (PK on user_data_ext).
-- Returns INTEGER rows-affected (0 if char has not yet logged in /
-- user_data_ext row absent; 1 on the normal path).
CREATE OR REPLACE FUNCTION aion_setcharexps_rewardnum(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    UPDATE user_data_ext
       SET exps_npckill_reward_num = exps_npckill_reward_num + 1
     WHERE char_id = _char_id;
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharexps_rewardnum(INTEGER);
-- +goose StatementEnd
