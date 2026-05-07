-- AionCore 5.8 — Sprint 1.1a batch 10 port: aion_DeleteAllPromotionCoolTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllPromotionCoolTime.sql
-- Original (T-SQL):
--   DELETE FROM user_promotion_cooltime WHERE promotion_id = @nPromotionId
--
-- Translation notes:
--   * Single-arg DELETE keyed on promotion_id only (NOT char_id) — this is
--     the **operator-side decommission SP**, not a player-action SP. When a
--     promotion ends server-wide (e.g. a 30-day login event wraps), the GM
--     tool calls this once to wipe every player's row for that promotion in
--     one shot. Per-player decommission is 00185 (DeletePromotionCoolTime).
--   * The T-SQL signature explicitly takes only @nPromotionId — task spec
--     line "by char_id" is a misread. Verified against the real source dump
--     at line 6-12 (single SMALLINT parameter, no char_id).
--   * Table user_promotion_cooltime created in 00181 (composite PK
--     char_id + promotion_id). Migration is order-independent because we do
--     not redeclare the table — goose enforces strict numeric ordering, so
--     00181 always runs first.
--   * Returns rows-affected so the caller can record "swept N rows" telemetry
--     after a promotion wraps. Matches the 00171 / 00185 convention.
--   * Function NOT declared STABLE — it mutates state.
--
-- Used by:
--   scripts/admin/promotion_decommission.lua  -- GM tool: wrap a server-wide promo
--   scripts/lib/promotion.lua                  -- (post-event cleanup helper)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallpromotioncooltime(SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
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
