-- AionCore 5.8 — Sprint 1.1a batch 2 port: aion_AddItemAmount.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddItemAmount.sql
-- Original (T-SQL):
--   UPDATE user_item SET amount = amount + @nAmount WHERE id = @nId
--   IF (@nAmount < 0)
--     UPDATE user_item Set warehouse=10, update_date=GETDATE()
--      WHERE id = @nId AND amount <= 0 AND name_id <> 182400001
--
-- Translation notes:
--   * Two-statement protocol preserved: first apply the delta, then sweep the
--     row into trash (warehouse=10) iff the result is non-positive AND the
--     amount was actually decreased AND the item is not Kinah (182400001 is
--     Kinah's name_id; Kinah balance is allowed to hit zero without being
--     trashed because it's the wallet, not stock).
--   * NCSoft used `GETDATE()` (T-SQL local-time wall clock); PG uses NOW()
--     for parity. update_date is TIMESTAMPTZ in our schema (00115 round 7),
--     so NOW() correctly stamps the soft-delete moment.
--   * The MARO comment in the original ("amount <= 0 part is tricky, but
--     must be HERE") refers to the race where a SetItemAmount path can
--     ALSO drop amount to 0; we keep the same semantics — only the negative-
--     delta caller pays the warehouse-10 sweep cost.
--
-- Returns the number of rows affected by the FIRST update (1 = item exists
-- and delta applied; 0 = item id unknown). The trash-sweep is observation-
-- only and not surfaced because callers don't act on it (Lua just refreshes
-- inventory after the call).
--
-- Used by:
--   scripts/lib/inventory.lua            -- consume / restock helpers
--   scripts/handlers/cm_loot_pickup.lua  -- partial-stack merge

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_additemamount(BIGINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_additemamount(
    _id      BIGINT,
    _amount  BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    UPDATE user_item
       SET amount = amount + _amount
     WHERE id = _id;
    GET DIAGNOSTICS affected = ROW_COUNT;

    -- Negative delta + post-update amount <= 0 + non-Kinah → archive to bin.
    IF _amount < 0 THEN
        UPDATE user_item
           SET warehouse   = 10,
               update_date = NOW()
         WHERE id = _id
           AND amount <= 0
           AND name_id <> 182400001;
    END IF;

    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_additemamount(BIGINT, BIGINT);
-- +goose StatementEnd
