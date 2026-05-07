-- AionCore 5.8 — Char 生命周期清理 batch 27 / 1 of 5: aion_ClearCharDeleteTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClearCharDeleteTime.sql
-- Original (T-SQL):
--   CREATE procedure [dbo].[aion_ClearCharDeleteTime]
--       @nCharId int
--   as
--   set nocount on
--   UPDATE user_data
--   SET delete_date = 0,
--       change_info_time = dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)
--   WHERE char_id = @nCharId
--   set nocount off
--
-- Translation notes:
--   * Cancels a pending soft-delete by zeroing user_data.delete_date and
--     bumping change_info_time. Invoked by CM_RESTORE_CHARACTER (player
--     clicks "cancel deletion" before the 7-day sweeper fires) and by the
--     GM tool's "undelete" action.
--   * NCSoft `SET NOCOUNT ON/OFF` is a SQL Server statement-counter switch
--     with no PG analogue; dropped (PG row counts are surfaced via
--     GET DIAGNOSTICS, but this SP does not need them).
--   * NCSoft @nCharId INT (32-bit signed) → PG INTEGER (matches).
--   * dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(), 0) → PG helper
--     GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0). The helper is
--     defined in 00006_sp_set_char_delete_time.sql (it returns the
--     unix-epoch INT for the supplied UTC timestamp, offset minutes
--     applied). Same call as the existing 00117 port — bug-for-bug pin.
--   * Returns VOID — the NCSoft body has no return value; widening to
--     INTEGER would diverge from the contract Lua callers expect (Lua
--     db.call() ignores empty result sets).
--
-- Bug-for-bug pin:
--   * Char_id not found → UPDATE matches 0 rows, no error. NCSoft does not
--     RAISERROR on miss (caller is the Lua restore flow which has
--     already validated the char exists via prior load SP); pinned.
--   * Idempotent — re-invoking on an already-zeroed delete_date is a no-op
--     except change_info_time is bumped to the current second; matches
--     NCSoft (the change_info_time write is unconditional).
--   * No table-level row lock (NCSoft has no UPDLOCK hint) — pinned.
--
-- Duplicate note:
--   * 00117 already ports the same SP from Round 10 F1. This entry is the
--     batch-27 char-lifecycle-cleanup sibling carrying expanded comments
--     and bug-for-bug audit. Function body is byte-identical to 00117 so
--     CREATE OR REPLACE makes the migration order-independent (whichever
--     runs last wins, both yield the same plpgsql body).
--
-- Used by:
--   scripts/handlers/cm_restore_character.lua  -- player cancels soft-delete
--   scripts/admin/gm_undelete_char.lua          -- GM "undelete" action

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearchardeletetime(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : char to un-mark (NCSoft @nCharId INT)
-- 返回 VOID — 与 NCSoft 原始无返回值契约对齐.
CREATE OR REPLACE FUNCTION aion_clearchardeletetime(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET delete_date      = 0,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearchardeletetime(INTEGER);
-- +goose StatementEnd
