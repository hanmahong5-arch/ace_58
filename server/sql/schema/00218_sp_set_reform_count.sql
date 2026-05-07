-- AionCore 5.8 — Sprint 1.1a batch 16 port: aion_SetReformCount (reform-count UPSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetReformCount.sql
-- Original (T-SQL):
--   UPDATE user_reform
--      SET next_reset_time=@next_reset_time, reform_count=@reform_count
--    WHERE char_id=@char_id
--
--   IF @@ROWCOUNT = 0
--   BEGIN
--       INSERT INTO user_reform(char_id, next_reset_time, reform_count)
--       VALUES (@char_id, @next_reset_time, @reform_count)
--   END
--
-- Translation notes:
--   * Sister of 00217 GetReformCount. Sets per-char weekly reform state.
--     The user_reform table + PK are created by 00217; this migration only
--     adds the function.
--   * NCSoft pattern: UPDATE-then-INSERT-if-no-row is the canonical pre-MERGE
--     SQL Server upsert. PG's ON CONFLICT (char_id) DO UPDATE collapses to
--     a single statement with identical observable behaviour.
--   * Returns rows-affected (1 for either insert or update branch). Mirrors
--     the precedent set by 00211 SetItemSealInfo / 00170 SetMacro and lets
--     the Lua caller distinguish "function ran" from a transport-level error.
--   * The 5.8 reform feature schedules the next_reset boundary on a fresh
--     write — typical pattern is: gameplay layer reads (Get), computes new
--     count and reset time, calls Set. No race-window concern: the upsert
--     is row-level atomic in PG.
--
-- Bug-for-bug:
--   * No clamp on negative reform_count or next_reset_time. NCSoft accepts
--     any 32-bit integer including negatives — useful for GM corrections
--     (e.g. give a player negative count = unlimited reforms this cycle).
--     Pinned verbatim — do NOT add CHECK constraints.
--   * No char_id existence check vs user_data — orphan-tolerant.
--   * 2038 overflow on next_reset_time INT — pinned (see 00217 header).
--
-- Used by:
--   scripts/handlers/cm_item_reform_apply.lua  (after successful reform)
--   scripts/lib/reform.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setreformcount(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setreformcount(
    _char_id          INTEGER,
    _next_reset_time  INTEGER,
    _reform_count     INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- UPSERT on PK(char_id). Both branches return 1 row affected — the
    -- caller cannot distinguish insert vs update from this return value
    -- (matches NCSoft semantics where both branches of the IF emit
    -- @@ROWCOUNT = 1).
    INSERT INTO user_reform (char_id, next_reset_time, reform_count)
    VALUES (_char_id, _next_reset_time, _reform_count)
    ON CONFLICT (char_id) DO UPDATE SET
        next_reset_time = EXCLUDED.next_reset_time,
        reform_count    = EXCLUDED.reform_count;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setreformcount(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
