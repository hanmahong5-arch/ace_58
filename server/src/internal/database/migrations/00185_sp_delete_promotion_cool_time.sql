-- AionCore 5.8 — Sprint 1.1a batch 10 port: aion_DeletePromotionCoolTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeletePromotionCoolTime.sql
-- Original (T-SQL):
--   DELETE FROM user_promotion_cooltime
--    WHERE char_id = @nCharId AND promotion_id = @nPromotionId
--
-- Translation notes:
--   * Single-row DELETE keyed on the composite PK (char_id, promotion_id) —
--     the **per-player counterpart** of 00184 (server-wide sweep). Used when
--     a single character's promotion progress needs to be reset (refund
--     handler, CS rollback, tester reset).
--   * Returns rows-affected so the caller can distinguish "row deleted" (1)
--     from "no-op on missing row" (0) — useful when the client UI may have
--     stale state and asks to clear a promo it has already finished. Matches
--     the 00171 (DelMacro) convention.
--   * Table user_promotion_cooltime created in 00181; migration order-
--     independent (goose enforces 00181 < 00185 numerically).
--   * Function NOT declared STABLE — it mutates state.
--
-- Used by:
--   scripts/handlers/cm_promotion_reset.lua    -- CS rollback / tester reset
--   scripts/lib/promotion.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepromotioncooltime(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletepromotioncooltime(
    _char_id      INTEGER,
    _promotion_id SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM user_promotion_cooltime
     WHERE char_id      = _char_id
       AND promotion_id = _promotion_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepromotioncooltime(INTEGER, SMALLINT);
-- +goose StatementEnd
