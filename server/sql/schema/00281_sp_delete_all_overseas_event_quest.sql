-- AionCore 5.8 — batch 28 / 1 of 5 ("Delete-族杂项"):
--   aion_DeleteAllOverseasEventQuest — wholesale wipe of the overseas-event
--   quest **whitelist** (no args, no filter).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllOverseasEventQuest.sql
-- Original (T-SQL):
--   CREATE PROCEDURE [dbo].[aion_DeleteAllOverseasEventQuest]
--   AS
--   BEGIN
--       SET NOCOUNT ON;
--       delete from overseas_event_quest;
--       SET NOCOUNT OFF;
--   END
--
-- Lineage note (batch 28 idempotent re-affirmation):
--   * The function body was first ported in 00187 (Sprint 1.1a batch 10).
--     This batch-28 migration RE-states the same definition via
--     CREATE OR REPLACE — goose-safe, identical body, identical signature.
--     Rationale: keep the "Delete-族杂项" cohort 00281-00285 grouped as a
--     single audit boundary so the new sp_delete_misc_test.go covers all
--     5 SPs from a single test file with a single char_id band, without
--     leaking semantics into the older batch-10 isolation surface.
--   * Underlying table `overseas_event_quest` is created by 00186; this
--     migration does NOT redefine it.
--
-- Translation notes:
--   * Wholesale wipe (no char_id, no quest_id filter). Used by the GM tool
--     when a new event cycle begins: clear, re-seed, ship. 00186
--     (PutOverseasEventQuest) is the re-seed SP.
--   * NOT a TRUNCATE — DELETE keeps PG sequence / WAL / bloat semantics
--     identical to SQL Server, AND lets the call return a row-count.
--     TRUNCATE would lose the row-count and have very different MVCC
--     visibility under a transaction.
--   * Returns rows-affected for telemetry ("swept N rows before re-seed").
--   * Function NOT declared STABLE — it mutates state.
--
-- Bug-for-bug:
--   * Empty-table sweep returns 0, no error. Pinned.
--   * No isolation by char_id — wipes EVERY row regardless of insert origin.
--     Pinned (NCSoft same).
--
-- Used by:
--   scripts/admin/overseas_event_reset.lua    -- GM tool: end an event cycle
--   scripts/lib/overseas_event.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletealloverseaseventquest();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletealloverseaseventquest()
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure wholesale DELETE; mirrors NCSoft @@ROWCOUNT contract.
    DELETE FROM overseas_event_quest;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- Down is a no-op for this batch-28 re-affirmation: dropping the function
-- here would also remove the body installed by 00187 and break older tests.
-- Goose runs Down in reverse; 00187's Down handles the actual teardown.
SELECT 1;
-- +goose StatementEnd
