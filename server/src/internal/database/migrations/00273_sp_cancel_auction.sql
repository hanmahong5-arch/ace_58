-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 5 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 历史 aion_setauctionstate(00067) 是房屋拍卖通用 state setter；本
--  SP 是物品拍卖专属撤拍，含所有权 + has_bids 双重校验)。
--
-- 职责：卖家主动撤拍。原子性：
--   1) 锁 listing 行 (FOR UPDATE)
--   2) 校验 state=0（active）
--   3) 校验 seller_char_id == 调用者 cid
--   4) 校验 current_bid == 0（已有人出价不让撤 — 防止卖家恶意躲单）
--   5) 翻 state → 1 (cancelled)
--
-- Lua 期望签名（scripts/lib/auction.lua:248）：
--   db.call("aion_CancelAuction", listing_id, cid)
--   → 任意（Lua 只看 err）
--
-- 失败用 RAISE EXCEPTION 上抛 — Lua db.call 收到 err 字串。
-- Lua 端 (auction.lua:222-256) 在调本 SP 之前已经做了
-- get_auction_by_id 预检（not_owner / has_bids 在 Lua 层就拒了），
-- 本 SP 的 RAISE 是 belt-and-suspenders（race / 并发场景兜底）。
--
-- 不退还 listing fee：lib/auction.lua header §13-14 明示 "auction.cancel
-- does NOT refund the fee to discourage spam listings"。SP 不动 user_item
-- 也不发邮件。
--
-- 用法：
--   scripts/lib/auction.lua → auction.cancel

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_cancelauction(BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _listing_id : 拍卖 ID
-- _seller_cid : 调用者 char_id（必须 == listing.seller_char_id）
-- 返回 0 行（VOID 风格 — pgx CallSP 当作空 set，Lua _, err = db.call() 拿到 err）
CREATE OR REPLACE FUNCTION aion_cancelauction(
    _listing_id BIGINT,
    _seller_cid INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    _row auction_listing%ROWTYPE;
BEGIN
    SELECT * INTO _row
      FROM auction_listing
     WHERE listing_id = _listing_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'cancel_auction: listing % not found', _listing_id;
    END IF;
    IF _row.state <> 0 THEN
        RAISE EXCEPTION 'cancel_auction: listing % not active (state=%)',
            _listing_id, _row.state;
    END IF;
    IF _row.seller_char_id <> _seller_cid THEN
        RAISE EXCEPTION 'cancel_auction: cid % is not seller (seller=%)',
            _seller_cid, _row.seller_char_id;
    END IF;
    IF _row.current_bid > 0 THEN
        RAISE EXCEPTION 'cancel_auction: listing % has bids (current_bid=%)',
            _listing_id, _row.current_bid;
    END IF;

    UPDATE auction_listing
       SET state = 1
     WHERE listing_id = _listing_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_cancelauction(BIGINT, INTEGER);
-- +goose StatementEnd
