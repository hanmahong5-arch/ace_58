-- AionCore 5.8 — Sprint 1.1a batch 18 port: aion_SetAuctionGrace
-- (housing auction grace state UPDATE).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetAuctionGrace.sql
-- Original (T-SQL):
--   update user_grace set state = @state where grace_id = @grace_id
--
-- Translation notes:
--   * Pure UPDATE on user_grace.state, scoped by PK (grace_id). Used to
--     transition a grace entry from active(0) to expired/acknowledged(>0)
--     once the new owner takes possession or the timer fires.
--   * Parameter widths verified against NCSoft schema:
--       @grace_id  INT   → BIGINT (mirrors 00227 BIGSERIAL widening; the
--                                  surrogate is BIGINT throughout PG even
--                                  though NCSoft schema kept it INT —
--                                  RPC layer up-casts on the wire)
--       @state     INT   → INTEGER (0 active / 1 expired / 2+ ack — see 00227)
--   * Returns rows-affected (1 on success / 0 if grace_id missing).
--     NCSoft @@ROWCOUNT pin — 0 is silent, no error.
--   * VOLATILE — data-modifying.
--
-- Bug-for-bug:
--   * No state-transition guard. NCSoft accepts any state value and any
--     monotonicity (you can flip 1→0→1, even though the auction logic
--     never does). Pinned — do NOT add CHECK or trigger.
--   * Negative state values are accepted by NCSoft (signed INT column);
--     observed in dev as flag values. Pinned.
--   * No update of starttime / owner_id / goods_id / building_id. The
--     other columns are immutable post-insert.
--
-- Used by:
--   scripts/handlers/cm_house_auction_grace_resolve.lua  (timer / takeover)
--   scripts/lib/auction.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctiongrace(BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setauctiongrace(
    _grace_id  BIGINT,
    _state     INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure UPDATE scoped by PK. 0 rows == grace_id missing (silent, no error).
    UPDATE user_grace
       SET state = _state
     WHERE grace_id = _grace_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctiongrace(BIGINT, INTEGER);
-- +goose StatementEnd
