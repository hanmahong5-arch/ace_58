-- AionCore 5.8 — Char 生命周期清理 batch 27 / 2 of 5: aion_DeleteAllAbnormalStatus.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllAbnormalStatus.sql
-- Original (T-SQL):
--   create procedure [dbo].[aion_DeleteAllAbnormalStatus]
--       @nCharId int
--   as
--   SET NOCOUNT ON
--   DELETE
--   FROM user_abnormal_status
--   WHERE char_id=@nCharId
--   set nocount off
--
-- Translation notes:
--   * Wipes every persisted buff/debuff for a single character. NCSoft
--     invokes this at logout (so a player cannot drink a 30 min
--     stat-boost potion → log out → log back in to extend the timer) and
--     during the character-purge cascade.
--   * NCSoft `SET NOCOUNT ON/OFF` dropped (no PG analogue).
--   * NCSoft @nCharId INT → PG INTEGER. Bug-for-bug pin (no widening).
--   * Returns VOID — the NCSoft body has no return value. We do NOT widen
--     to INTEGER rows-affected here even though the cascade convention in
--     batches 18/22/26 widens delete-by-key SPs; this SP's contract is
--     "wipe all rows for char_id, do not care about count" and matches
--     the sister Round-10 cascade entries (00120 DeleteAllSkill, 00121
--     DeleteAllQuest, 00122 DeleteAllAbnormalStatus all RETURNS VOID).
--
-- Bug-for-bug pin:
--   * char_id with no rows → DELETE affects 0 rows, no error. Pinned.
--   * Idempotent — second invocation on an empty char_id is a no-op.
--   * No FK cascades from user_abnormal_status (PK is composite
--     (char_id, abnormal_id) with no outbound references).
--   * NCSoft has no DELETETOP / batched delete; we wipe in one statement.
--     A character with thousands of stale rows is not realistic (5.8
--     limits abnormal_status rows to active buffs only via PUT logic),
--     so single-shot DELETE is safe.
--
-- Duplicate note:
--   * 00122 already ports the same SP from Round 10 F1. This entry carries
--     batch-27 expanded audit notes; SP body byte-identical so
--     CREATE OR REPLACE keeps the migrations order-independent.
--
-- Used by:
--   scripts/handlers/cm_logout.lua             -- logout flush
--   scripts/admin/gm_clear_buffs.lua            -- GM "wipe all buffs" tool
--   scripts/lib/char_purge.lua                  -- delete-cascade helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallabnormalstatus(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : char to wipe buffs for (NCSoft @nCharId INT)
-- 返回 VOID.
CREATE OR REPLACE FUNCTION aion_deleteallabnormalstatus(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_abnormal_status WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallabnormalstatus(INTEGER);
-- +goose StatementEnd
