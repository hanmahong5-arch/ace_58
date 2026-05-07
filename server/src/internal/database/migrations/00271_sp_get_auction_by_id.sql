-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 3 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 历史 aion_GetAuctionState_20110609 / aion_GetAuctionList_110628 服务的
--  是房屋拍卖；本 SP 是物品拍卖单条查询，列字段名跟 Lua 字段对位严格)。
--
-- 职责：单条 listing 的 read-only 查询，被 auction.bid / auction.cancel
-- 在写之前调用做合法性校验。
--
-- Lua 期望签名（scripts/lib/auction.lua:180, 233）：
--   db.call("aion_GetAuctionById", listing_id) → 1 行
--   row.seller_char_id（或 row.seller_cid 兼容兜底）
--   row.expires_at
--   row.current_bid
--   row.min_bid
--
-- 设计选择：
--   - 返回 0 行（找不到）→ Lua 翻译为 "not_found"
--   - 不过滤 state（settled/cancelled 也返回）→ Lua 端用 expires_at 判过期，
--     state 信息可选透出（settle 已自动判终态；cancel 在 Lua 用 has_bids 判）。
--   - 列名严格匹配 Lua row.xxx — seller_char_id 优先，但 seller_cid 也 alias
--     输出（Lua 是 `row.seller_char_id or row.seller_cid` — 第一个匹配即可）。
--   - 包含 seller_name / item_id / item_count / buy_now / state — 让本 SP 也
--     能服务 future "客户端单条查询包"，复用率最大化。
--
-- 用法：
--   scripts/lib/auction.lua → auction.bid（出价前预检）
--   scripts/lib/auction.lua → auction.cancel（撤拍前预检）

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionbyid(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _listing_id : 拍卖 ID
-- 返回 0 或 1 行；列名与 Lua 期望严格对位。
CREATE OR REPLACE FUNCTION aion_getauctionbyid(_listing_id BIGINT)
RETURNS TABLE (
    listing_id          BIGINT,
    seller_char_id      INTEGER,
    seller_name         VARCHAR(20),
    item_id             INTEGER,
    item_count          INTEGER,
    min_bid             BIGINT,
    buy_now             BIGINT,
    current_bid         BIGINT,
    current_bidder_cid  INTEGER,
    expires_at          INTEGER,
    state               SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT  al.listing_id,
                al.seller_char_id,
                al.seller_name,
                al.item_id,
                al.item_count,
                al.min_bid,
                al.buy_now,
                al.current_bid,
                al.current_bidder_cid,
                al.expires_at,
                al.state
          FROM auction_listing al
         WHERE al.listing_id = _listing_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionbyid(BIGINT);
-- +goose StatementEnd
