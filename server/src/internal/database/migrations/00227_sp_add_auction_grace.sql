-- AionCore 5.8 — Sprint 1.1a batch 18 port: aion_AddAuctionGrace
-- (housing-auction grace-period INSERT, returns identity).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddAuctionGrace.sql
-- Original (T-SQL):
--   insert into user_grace
--     (owner_id, goods_id, building_id, starttime, state)
--     values (@ownerid, @goodsid, @buildingid, @starttime, 0)
--   return @@identity
--
-- Translation notes:
--   * Logs a "grace period" entry — when the previous owner of an
--     auctioned house is given a window to vacate / move belongings before
--     the new owner can move in. state=0 means "grace active"; state>0
--     marks resolution (handled by 00228 SetAuctionGrace).
--   * `user_grace` table is **first introduced here**. Column names follow
--     NCSoft 5.8 verbatim (owner_id / goods_id / building_id / starttime /
--     state, snake_case lowercase — no quoting needed).
--   * Parameter widths verified against NCSoft schema:
--       @ownerid     INT   → INTEGER (char_id of departing owner)
--       @goodsid     INT   → INTEGER (auction goods id, joins user_auction.goodsID)
--       @buildingid  INT   → INTEGER (assigned house instance id)
--       @starttime   INT   → INTEGER (epoch seconds, NCSoft pin — not BIGINT)
--   * Returns BIGINT — the freshly-allocated grace_id surrogate.
--     T-SQL `@@identity` becomes RETURNING grace_id INTO _new_id (precedent
--     established by 00066 aion_addAuction).
--   * BIGSERIAL chosen for grace_id because the auction housing churn over
--     a long-running 5.8 server can plausibly outgrow INT (NCSoft ran INT
--     and never overflowed — pinned at BIGINT to be safer; 5.8 client
--     reads the response as INT-or-wider via the RPC layer).
--   * VOLATILE — data-modifying.
--
-- Bug-for-bug:
--   * No FK on owner_id, goods_id, or building_id — orphan grace rows can
--     outlive the relevant char / auction / house. NCSoft mirrors.
--   * starttime is stored verbatim (no clamp / no NOW() override). Caller
--     decides the epoch — the auction settle handler computes "old owner
--     vacate deadline" and passes the epoch in.
--   * Initial state is hard-pinned at 0. NCSoft has no SP to insert with
--     a different state; the only writes that flip state are via 00228.
--
-- Used by:
--   scripts/handlers/cm_house_auction_settle.lua  (auction wins → grace)
--   scripts/lib/auction.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_grace — first introduction. Tracks "previous owner vacate window"
-- after an auction settles. state: 0 active, 1 expired, 2+ acknowledged.
-- Indexed on state for the hot-path GetAuctionGraceList scan (state=0).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_grace (
    grace_id     BIGSERIAL PRIMARY KEY,
    owner_id     INTEGER   NOT NULL,
    goods_id     INTEGER   NOT NULL,
    building_id  INTEGER   NOT NULL,
    starttime    INTEGER   NOT NULL,
    state        INTEGER   NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_grace_state ON user_grace(state);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauctiongrace(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addauctiongrace(
    _owner_id     INTEGER,
    _goods_id     INTEGER,
    _building_id  INTEGER,
    _starttime    INTEGER
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _new_id BIGINT;
BEGIN
    -- T-SQL `return @@identity` → PG RETURNING grace_id INTO local var.
    -- state hard-pinned at 0 per NCSoft; only 00228 mutates it.
    INSERT INTO user_grace (owner_id, goods_id, building_id, starttime, state)
    VALUES (_owner_id, _goods_id, _building_id, _starttime, 0)
    RETURNING grace_id INTO _new_id;

    RETURN _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauctiongrace(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_grace_state;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_grace;
-- +goose StatementEnd
