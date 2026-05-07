-- AionCore 5.8 — Char 生命周期清理 batch 27 / 4 of 5: aion_DeleteAllPromotionCoolTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllPromotionCoolTime.sql
-- Original (T-SQL):
--   create procedure [dbo].[aion_DeleteAllPromotionCoolTime]
--       @nPromotionId smallint
--   as
--   SET NOCOUNT ON
--   DELETE
--   FROM user_promotion_cooltime
--   WHERE promotion_id=@nPromotionId
--   set nocount off
--
-- Translation notes:
--   * **NOT a per-character SP** — keyed on @nPromotionId only, NOT
--     @nCharId. This is the operator-side decommission SP: when a
--     server-wide promotion ends (e.g. a 30-day login event wraps), the
--     GM tool calls this once to wipe every player's cooltime row for
--     that promotion in one shot. Per-character per-promotion decommission
--     is 00185 (DeletePromotionCoolTime) which takes (char_id, promo_id).
--   * Despite living in the "Char 生命周期清理" batch theme, this SP is
--     **not** part of the per-character delete cascade — it is included
--     here because the cleanup theme spans both per-char AND server-wide
--     post-event sweeps (operator vs player driven cleanup, both flavors
--     of "remove obsolete user_* rows"). Pinned per task spec.
--   * NCSoft `SET NOCOUNT ON/OFF` dropped.
--   * NCSoft @nPromotionId SMALLINT → PG SMALLINT (matches; not widened
--     to INTEGER even though Go callers pass int — pgx does the cast).
--     Width matters because user_promotion_cooltime.promotion_id is
--     declared SMALLINT and a width-mismatched call signature would force
--     an extra cast on the SP's predicate side.
--   * Returns INTEGER (rows affected) so the caller can record "swept N
--     rows" telemetry after a promotion wraps. Matches the 00185 / 00171
--     widening convention. NOTE: this DIVERGES from sister cascade SPs
--     (00276/00277/00278/00280) which all return VOID — but the divergence
--     is intentional (per-promotion sweep needs the count for ops
--     telemetry). Documented bug-for-bug pin against the existing 00184
--     port behavior.
--   * Function NOT declared STABLE — it mutates state.
--
-- Bug-for-bug pin:
--   * @nPromotionId with no rows → DELETE affects 0 rows, returns 0, no
--     error. NCSoft does not RAISERROR; pinned.
--   * Idempotent — second invocation on an already-swept promotion
--     returns 0.
--   * Spans every char_id — a player whose cooltime has not yet expired
--     loses it on cleanup (this is the intended decommission semantic;
--     the promo is over, the cooltime is meaningless).
--   * SMALLINT range -32768..32767 — promo IDs in 5.8 production are
--     under 1000, so the SMALLINT bound is comfortable. If a future
--     content patch ever exceeds 32767, this SP signature must be widened
--     in tandem with 00115/00181 schema and 00182/00185 callers.
--
-- Duplicate note:
--   * 00184 already ports the same SP (batch 10 — "Q1 末 50 SP 目标达成").
--     This entry is the batch-27 char-lifecycle-cleanup sibling carrying
--     expanded audit notes. Function body is byte-identical to 00184 so
--     CREATE OR REPLACE keeps the migrations order-independent.
--
-- Used by:
--   scripts/admin/promotion_decommission.lua   -- GM tool: wrap server-wide promo
--   scripts/lib/promotion.lua                   -- post-event cleanup helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallpromotioncooltime(SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _promotion_id : promo to decommission (NCSoft @nPromotionId SMALLINT)
-- 返回 INTEGER 行数 — 用于 ops 遥测 "wrap N rows".
CREATE OR REPLACE FUNCTION aion_deleteallpromotioncooltime(
    _promotion_id SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM user_promotion_cooltime
     WHERE promotion_id = _promotion_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallpromotioncooltime(SMALLINT);
-- +goose StatementEnd
