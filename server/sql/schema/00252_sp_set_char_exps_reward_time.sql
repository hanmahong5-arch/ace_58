-- AionCore 5.8 — Sprint 1.1a batch 23 port: aion_SetCharEXPS_RewardTime
-- (login-reward bookkeeping: stamp the last login-reward epoch and reset
--  the npc-kill counter — paired with 00253 SetCharEXPS_RewardNum).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharEXPS_RewardTime.sql
-- Original (T-SQL):
--   IF not exists (select char_id from user_data_ext(updlock) where char_id = @charId)
--       insert into user_data_ext (char_id, exps_login_reward_time, exps_npckill_reward_num)
--       values(@charId, @rewardTime, 0)
--   ELSE
--       UPDATE user_data_ext
--       SET exps_login_reward_time = @rewardTime, exps_npckill_reward_num = 0
--       where char_id = @charId
--
-- Domain (NEW — `char_exps_reward` is not previously touched):
--   `EXPS` = Experience Points System — NCSoft's daily login-reward stream
--   (separate from regular XP). Each login stamps a new epoch; subsequent
--   NPC kills increment a counter (00253) up to a cap. The two-SP pair
--   tracks (last_login_epoch, kills_since_login) on user_data_ext.
--
-- Schema:
--   user_data_ext was introduced at 00236 (familiar_energy / autocharge /
--   last_summon_familiar). It is the canonical 1:1 cold side-table on
--   user_data. NCSoft live schema (AionWorldLive.user_data_ext) carries
--   16 columns; this batch adds the two needed for the EXPS pair using
--   `ALTER TABLE … ADD COLUMN IF NOT EXISTS` (PG 9.6+ idempotent — safe
--   on re-run, safe on a fresh DB where 00236 just created the table).
--
-- Translation notes:
--   * `(updlock)` table hint → ON CONFLICT … DO UPDATE (PG 9.5+ UPSERT is
--     race-safe via the PK and is a strict superset of the IF EXISTS +
--     UPDLOCK pattern used by NCSoft).
--   * NCSoft hardcodes `exps_npckill_reward_num = 0` on BOTH branches —
--     INSERT default and UPDATE assignment. Pinned: a fresh login wipes
--     the kill counter regardless of prior state. Mirrored exactly.
--   * `int` → INTEGER. NCSoft's @rewardTime is a 32-bit unix-epoch-second.
--     Pinned (NOT bigint — would overflow on 2038-01-19; NCSoft never
--     fixed this, and we mirror).
--   * VOID return — caller cannot tell INSERT vs UPDATE branch.
--
-- Bug-for-bug:
--   * 2038 overflow on @rewardTime is pinned (matches NCSoft behaviour).
--     Future widening to BIGINT must come with a coordinated NCSoft
--     SP-source bump and is OUT OF SCOPE for this batch.
--   * Other 14 user_data_ext columns are LEFT AT THEIR DEFAULTS on the
--     INSERT branch. Pinned: NCSoft does not write them either.
--
-- Used by:
--   scripts/events/on_login.lua            -- per-login reward stamp
--   scripts/lib/exps_reward.lua            -- shared EXPS helper

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_data_ext column widening — additive (idempotent ADD COLUMN IF
-- NOT EXISTS, PG 9.6+). Defaults match NCSoft live schema (0 / 0).
-- ====================================================================
ALTER TABLE user_data_ext
    ADD COLUMN IF NOT EXISTS exps_login_reward_time  INTEGER NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_data_ext
    ADD COLUMN IF NOT EXISTS exps_npckill_reward_num INTEGER NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharexps_rewardtime(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id     : owning char_id (PK on user_data_ext).
-- _reward_time : caller-supplied epoch-seconds of THIS login. NCSoft int
--                (32-bit) — kept narrow, do not widen. See 2038 note.
CREATE OR REPLACE FUNCTION aion_setcharexps_rewardtime(
    _char_id     INTEGER,
    _reward_time INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- T-SQL: IF NOT EXISTS … INSERT / ELSE UPDATE → PG ON CONFLICT UPSERT.
    -- `exps_npckill_reward_num = 0` on BOTH branches: pinned. Each login
    -- resets the kill counter, regardless of prior state.
    INSERT INTO user_data_ext (char_id,
                               exps_login_reward_time,
                               exps_npckill_reward_num)
    VALUES (_char_id, _reward_time, 0)
    ON CONFLICT (char_id) DO UPDATE
       SET exps_login_reward_time  = EXCLUDED.exps_login_reward_time,
           exps_npckill_reward_num = 0;  -- pinned: wipes counter.
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharexps_rewardtime(INTEGER, INTEGER);
-- +goose StatementEnd

-- Note on Down: we do NOT drop the user_data_ext columns added above. Doing
-- so would lose data and break sister SPs (00253) that depend on the same
-- columns. The ADD COLUMN IF NOT EXISTS pattern is non-destructive and the
-- migration is intended to be append-only past this point.
