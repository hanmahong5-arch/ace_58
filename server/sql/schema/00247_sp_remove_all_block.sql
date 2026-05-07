-- AionCore 5.8 — Sprint 1.1a batch 22 port: aion_RemoveAllBlock
-- (purge ALL block-list entries that touch a given char, both sides).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_RemoveAllBlock.sql
-- Original (T-SQL):
--   DELETE FROM user_block WHERE char_id  = @nCharId
--   DELETE FROM user_block WHERE block_id = @nCharId
--
-- Schema:
--   user_block already created in 00072 (pve scaffold round 5) with
--   composite PK (char_id, block_id). We DO NOT re-create. RemoveAllBlock
--   wipes BOTH directions in a single call — NCSoft semantics is "this
--   char no longer participates in any block relationship".
--
-- Translation notes:
--   * Two literal DELETE statements in T-SQL → two UPDATEs concatenated
--     in plpgsql. Order is irrelevant — the two predicates are disjoint
--     unless char_id == block_id (self-block, an edge case which we still
--     handle correctly: row matches both predicates, deleted by the first
--     DELETE, second DELETE is then a no-op for that row).
--   * Returns total rows-affected so the Lua caller can log "purged N
--     entries". NCSoft contract was VOID; we widen to INTEGER as a strict
--     superset (Lua callers may ignore the return). This matches the
--     pattern used in 00081 sp_remove_pet (which also returns rows-affected
--     for the equivalent two-side cleanup).
--   * No batching / transaction — both DELETEs run inside a single SP call,
--     which goose/pgx executes inside one transaction by default.
--
-- Bug-for-bug:
--   * No FK on user_block.char_id or user_block.block_id. We delete by the
--     int value alone — orphan rows (block_id pointing at deleted char)
--     are still purged. Pinned (matches NCSoft's deliberate denormalization).
--   * Self-block (char_id == block_id == @nCharId) is correctly purged by
--     either DELETE. Pinned.
--   * If the char has zero block entries on either side, the SP is a no-op
--     and returns 0. Pinned (no exception, no notice).
--
-- Used by:
--   scripts/handlers/cm_unblock_all.lua    -- player "unblock everyone" command
--   scripts/lib/account_purge.lua          -- account-deletion cleanup chain

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeallblock(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : the focal char whose block-list participation is being purged.
--            We remove rows where _char_id appears EITHER as the blocker
--            (char_id) or as the target (block_id), in two passes.
CREATE OR REPLACE FUNCTION aion_removeallblock(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_a INTEGER;
    affected_b INTEGER;
BEGIN
    -- Side A: rows where _char_id is the blocker.
    DELETE FROM user_block WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_a = ROW_COUNT;

    -- Side B: rows where _char_id is the blocked target. NCSoft runs
    -- this DELETE second; if a self-block row existed it was already
    -- deleted by side A (no double-decrement, ROW_COUNT here is 0 for
    -- that row).
    DELETE FROM user_block WHERE block_id = _char_id;
    GET DIAGNOSTICS affected_b = ROW_COUNT;

    RETURN affected_a + affected_b;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeallblock(INTEGER);
-- +goose StatementEnd
