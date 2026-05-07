-- AionCore 5.8 — batch 28 / 3 of 5 ("Delete-族杂项"):
--   aion_DeleteBookmarkAll — per-char bookmark wipe.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteBookmarkAll.sql
-- Original (T-SQL):
--   create procedure [dbo].[aion_DeleteBookmarkAll]
--       @nCharId int
--   AS
--   set nocount on
--   DELETE bookmark WHERE char_id = @nCharId
--   set nocount off
--
-- Lineage note (batch 28 idempotent re-affirmation):
--   * First ported in 00201 (Sprint 1.1a batch 13) — same body, same args.
--     Re-stated here for cohort grouping; goose-safe CREATE OR REPLACE.
--     Underlying table `bookmark` is declared in 00164; this migration
--     does NOT redefine it.
--
-- Translation notes:
--   * Pure per-char wipe of every bookmark row the player owns. Used in
--     two places NCSoft documents:
--       a) /bookmark clearall  — explicit user gesture
--       b) char-delete cascade — when DeleteChar runs, this is called as
--          part of the cleanup chain (mirrored in 00131-ish family for
--          full delete).
--   * NO existence guard, NO error on empty result. char_id with zero
--     rows returns rowsaffected=0 silently — same as T-SQL. This is the
--     operational contract clear-on-empty.
--   * Returns rows-affected so callers can log "X bookmarks wiped" or
--     detect the missing-char case. NCSoft itself ignores the return
--     value but the metric is too cheap to drop.
--
-- Bug-for-bug:
--   * No FK guard on char_id — accepts any INTEGER; missing user_data
--     parent is silently OK. Pinned (NCSoft same).
--   * Empty result returns 0, no error. Pinned.
--
-- Used by:
--   scripts/handlers/cm_bookmark_clear.lua    -- on /bookmark clearall
--   scripts/lib/char_delete.lua               -- char delete cascade

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletebookmarkall(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : owning char_id whose bookmark rows are wiped wholesale.
-- Returns INTEGER rows-affected (0 on empty, N on wipe).
CREATE OR REPLACE FUNCTION aion_deletebookmarkall(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM bookmark WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- Down is a no-op (see 00281 Down rationale — preserve 00201's body).
SELECT 1;
-- +goose StatementEnd
