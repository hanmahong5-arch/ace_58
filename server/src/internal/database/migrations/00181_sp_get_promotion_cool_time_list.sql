-- AionCore 5.8 — Sprint 1.1a batch 9 port: aion_GetPromotionCoolTimeList_0724.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetPromotionCoolTimeList_0724.sql
-- Original (T-SQL):
--   SELECT promotion_id, last_promotion_time, received_item_count,
--          cycle_received_item_count, cycle_next_reset_time
--     FROM user_promotion_cooltime
--    WHERE char_id = @nCharId
--
-- Translation notes:
--   * Per-character list of in-flight promotion (event/login-reward) cooldowns.
--     `promotion_id`        — small enum identifying which promotion.
--     `last_promotion_time` — UNIX seconds of the last claim, drives the
--                             "every N hours" tick gate.
--     `received_item_count` — running total since promotion start, drives the
--                             "max M rewards over the entire promo" cap.
--     `cycle_received_item_count` + `cycle_next_reset_time` — sub-cycle pair
--                             for daily/weekly windows that reset under the
--                             umbrella of the longer promotion (e.g. 30-day
--                             promo with daily 5-claim cap).
--   * Table created here as the first consumer in the SP catalogue. SP 00182
--     (SetPromotionCooltime) writes the same shape via UPSERT.
--   * Composite PK (char_id, promotion_id): a char owns at most 1 row per
--     promotion. SP 00182 ON CONFLICT keys on this PK.
--   * Function declared STABLE — pure read, identical input always yields
--     identical output within a transaction snapshot.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua    -- promotion cooldown hydration
--   scripts/lib/promotion.lua

-- +goose Up
-- +goose StatementBegin
-- 00115 (round7 scaffold) pre-created the table with a single placeholder
-- column (next_avail_time TIMESTAMPTZ).  Round 8 / batch 9 finalises the
-- shape: 4 INTEGER cooldown fields matching the NCSoft T-SQL contract.
-- We additively migrate the existing table so a fresh DB and an upgraded
-- DB end up identical.
CREATE TABLE IF NOT EXISTS user_promotion_cooltime (
    char_id                   INTEGER  NOT NULL,
    promotion_id              SMALLINT NOT NULL,
    last_promotion_time       INTEGER  NOT NULL DEFAULT 0,
    received_item_count       INTEGER  NOT NULL DEFAULT 0,
    cycle_received_item_count INTEGER  NOT NULL DEFAULT 0,
    cycle_next_reset_time     INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, promotion_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_promotion_cooltime
    ADD COLUMN IF NOT EXISTS last_promotion_time       INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS received_item_count       INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cycle_received_item_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cycle_next_reset_time     INTEGER NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
-- 00115's placeholder TIMESTAMPTZ column has no consumers; drop it now that
-- the canonical INTEGER columns are in place.
ALTER TABLE user_promotion_cooltime
    DROP COLUMN IF EXISTS next_avail_time;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpromotioncooltimelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpromotioncooltimelist(_char_id INTEGER)
RETURNS TABLE (
    promotion_id              SMALLINT,
    last_promotion_time       INTEGER,
    received_item_count       INTEGER,
    cycle_received_item_count INTEGER,
    cycle_next_reset_time     INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT upc.promotion_id,
               upc.last_promotion_time,
               upc.received_item_count,
               upc.cycle_received_item_count,
               upc.cycle_next_reset_time
          FROM user_promotion_cooltime upc
         WHERE upc.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpromotioncooltimelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_promotion_cooltime;
-- +goose StatementEnd
