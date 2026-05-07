-- AionCore 5.8 — Sprint 1.1a batch 18 port: aion_AddAuctionFilterList
-- (housing auction goods block-list INSERT-IF-NOT-EXISTS).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddAuctionFilterList.sql
-- Original (T-SQL):
--   if EXISTS(select filterid from user_auctionfilter where goodsID = @goods)
--       return
--   else
--       insert into user_auctionfilter (type, goodsID) values(@type, @goods)
--
-- Translation notes:
--   * Adds a goods_id to the per-character / per-type "do not show me this
--     building" filter for housing auctions. The 5.8 client sends one of
--     these whenever the player ticks the "hide" checkbox in the auction
--     UI; the auction list (00070) excludes any goods present here.
--   * Parameter widths verified against NCSoft schema:
--       @type    INT   → INTEGER (auction class bucket — estate/villa/...)
--       @goods   INT   → INTEGER (building/goods nameid)
--   * `user_auctionfilter` table was already scaffolded in 00052
--     (round-4) with PK filterid BIGSERIAL + UNIQUE(type, goodsID). The
--     UNIQUE constraint catches duplicate (type, goodsID) pairs that the
--     EXISTS check below misses (cross-type collisions on the same goods).
--
-- Bug-for-bug:
--   * EXISTS check matches ONLY on goodsID — NOT on (type, goodsID).
--     Concretely: if the player already filtered goods_id 99 under type 1,
--     a subsequent attempt to filter the same goods_id 99 under type 2
--     also short-circuits and inserts nothing. NCSoft pinned this; we
--     mirror exactly. Effect is benign because the auction UI buckets by
--     type and a goods_id only ever lives in one type.
--   * No `RETURN` value carried back to the caller in T-SQL — the proc is
--     fire-and-forget. We surface rows-affected (0 = blocked by EXISTS,
--     1 = inserted) for caller observability without changing semantics.
--   * No char_id / owner column — the filter is **server-wide**, not
--     per-character. NCSoft made this choice consciously (the auction is
--     a shared housing market). Pinned verbatim.
--   * No FK on goodsID — orphan filter rows are accepted (NCSoft
--     has no FK either; goods catalog lives in client XML).
--
-- Used by:
--   scripts/handlers/cm_house_auction_filter_add.lua  (player hides a goods)
--   scripts/lib/auction.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauctionfilterlist(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addauctionfilterlist(
    _type   INTEGER,
    _goods  INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Bug-for-bug: EXISTS guards on goodsID alone, not (type, goodsID).
    -- A goods_id already filtered under any type blocks subsequent inserts
    -- under any other type. NCSoft pin — do not "fix" this to (type,goodsID).
    IF EXISTS (SELECT 1 FROM user_auctionfilter WHERE goodsID = _goods) THEN
        RETURN 0;
    END IF;

    INSERT INTO user_auctionfilter (type, goodsID) VALUES (_type, _goods);
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauctionfilterlist(INTEGER, INTEGER);
-- +goose StatementEnd
