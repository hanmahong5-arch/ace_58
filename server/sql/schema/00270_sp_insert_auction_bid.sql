-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 2 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 没有 InsertAuctionBid 这个 SP — house auction 用 user_betting 单条
--  upsert；本 SP 是物品拍卖独立设计的多条出价历史 + 当前最高价更新)。
--
-- 职责：
--   1) 创建 auction_bid 表 — 出价历史（审计 / 退款用）。
--   2) 创建 aion_insertauctionbid() — 单 transaction 内：
--      a. 校验 listing 处于 active 态（state=0）且未到期；
--      b. 插入 bid 行；
--      c. 更新 auction_listing.current_bid / current_bidder_cid。
--      竞争控制：FOR UPDATE 锁住 listing 行，避免双方同时出价产生丢失。
--
-- Lua 期望签名（scripts/lib/auction.lua:207）：
--   db.call("aion_InsertAuctionBid", listing_id, cid, amount)
--   → 任意（Lua 只看 err；err==nil 即成功）
--
-- 不在 SP 内做 escrow — Lua 已经在 player.spend_kinah 里扣完钱才调本 SP；
-- SP 的失败（state≠0 / expired / amount < required）通过 RAISE 上抛。
-- Lua 端捕获 err 后会 player.add_kinah 回滚（auction.lua:209）。
--
-- 用法：
--   scripts/lib/auction.lua → auction.bid

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- auction_bid — 出价历史表（首次引入）。
-- 每次成功出价插入一行；当前最高价同步落到 auction_listing.current_bid。
-- 多行出价用于 Phase S-17 退款工作器（aion_RefundBidder 未来 SP）。
-- ====================================================================
CREATE TABLE IF NOT EXISTS auction_bid (
    bid_id      BIGSERIAL  PRIMARY KEY,
    listing_id  BIGINT     NOT NULL,
    bidder_cid  INTEGER    NOT NULL,
    amount      BIGINT     NOT NULL,
    bid_at      INTEGER    NOT NULL
);
-- +goose StatementEnd

-- +goose StatementBegin
-- 退款工作器需要按 listing_id 倒序找上一个出价人
CREATE INDEX IF NOT EXISTS idx_auction_bid_listing
    ON auction_bid (listing_id, bid_id DESC);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_insertauctionbid(BIGINT, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _listing_id  : 拍卖 ID
-- _bidder_cid  : 出价人 char_id
-- _amount      : 出价金额（已被 Lua 端 spend_kinah 扣掉）
--
-- 返回 1 行 { bid_id BIGINT }（Lua 不读，但 RETURNS TABLE 形式与其他
-- SP 风格一致 — pgx CallSP 默认 SELECT * FROM ()）。
--
-- 失败情况（RAISE EXCEPTION，Lua db.call 收到 err）：
--   - listing 不存在 / 已结束 / 已撤销 / 已结算
--   - amount < 当前最高价 + 1
--   - 出价人 == 卖家（防御性 — Lua 已校验，这是 SP 端 belt-and-suspenders）
--
-- 并发：FOR UPDATE 锁住 listing 行 → 同一 listing 多人同时出价串行化。
CREATE OR REPLACE FUNCTION aion_insertauctionbid(
    _listing_id  BIGINT,
    _bidder_cid  INTEGER,
    _amount      BIGINT
) RETURNS TABLE (
    bid_id BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
    _row      auction_listing%ROWTYPE;
    _now      INTEGER := EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER;
    _required BIGINT;
    _new_id   BIGINT;
BEGIN
    -- 锁 listing 行，防止双方同步出价丢失
    SELECT * INTO _row
      FROM auction_listing
     WHERE listing_id = _listing_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'auction_bid: listing % not found', _listing_id;
    END IF;
    IF _row.state <> 0 THEN
        RAISE EXCEPTION 'auction_bid: listing % not active (state=%)',
            _listing_id, _row.state;
    END IF;
    IF _row.expires_at <= _now THEN
        RAISE EXCEPTION 'auction_bid: listing % expired (expires_at=%, now=%)',
            _listing_id, _row.expires_at, _now;
    END IF;
    IF _row.seller_char_id = _bidder_cid THEN
        RAISE EXCEPTION 'auction_bid: bidder is seller (cid=%)', _bidder_cid;
    END IF;

    -- 出价递增校验：必须 >= 当前最高 + 1（首次出价则 >= min_bid）
    IF _row.current_bid > 0 THEN
        _required := _row.current_bid + 1;
    ELSE
        _required := _row.min_bid;
    END IF;
    IF _amount < _required THEN
        RAISE EXCEPTION 'auction_bid: amount % < required %', _amount, _required;
    END IF;

    -- 插入历史
    INSERT INTO auction_bid (listing_id, bidder_cid, amount, bid_at)
    VALUES (_listing_id, _bidder_cid, _amount, _now)
    RETURNING auction_bid.bid_id INTO _new_id;

    -- 更新当前最高
    UPDATE auction_listing
       SET current_bid        = _amount,
           current_bidder_cid = _bidder_cid
     WHERE listing_id = _listing_id;

    RETURN QUERY SELECT _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_insertauctionbid(BIGINT, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_auction_bid_listing;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS auction_bid;
-- +goose StatementEnd
