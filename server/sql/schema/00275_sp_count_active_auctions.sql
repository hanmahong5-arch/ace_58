-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 7 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 没有这个 SP — house auction 没配额限制；本 SP 是物品拍卖
--  防 spam 的配额计数，对应 lua auction.MAX_ACTIVE_PER_USER = 15)。
--
-- 职责：返回卖家当前 *active* 上架数（state=0 且 expires_at>now）。
--
-- Lua 期望签名（scripts/lib/auction.lua:94）：
--   db.call("aion_CountActiveAuctions", cid)
--   → rows[1].count  (或 .active 兜底兼容)
--
-- 列名严格走 Lua 第一选择 "count"（auction.lua:96 `rows[1].count or
-- rows[1].active`）— 我们用 count，简洁，索引命中 idx_auction_listing_seller_active
-- 部分索引。
--
-- 设计决策：是否计入 expires_at>now？
--   - 计入 → 只统计真正占用配额的 listing；过期但未结算的不算。
--   - 不计 → 严格按 state=0；过期 sweep lag 期间也算占配额。
--   - 选 "计入" — 玩家 UX 友好（asynq lag 期间不会被锁住继续上架）；
--     state=0 + expires_at>now 也是 idx 部分索引的精确匹配条件中的一半。
--   - 备选索引可走 idx_auction_listing_seller_active (seller_char_id) WHERE
--     state=0；expires_at 过滤是行级 filter，配额 ≤15 行数据小，可接受。
--
-- 用法：
--   scripts/lib/auction.lua → auction.register（上架前预检）

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_countactiveauctions(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _seller_cid : 卖家 char_id
-- 返回 1 行 { count BIGINT } — Lua tonumber() 会兼容 BIGINT/INT/string。
CREATE OR REPLACE FUNCTION aion_countactiveauctions(
    _seller_cid INTEGER
) RETURNS TABLE (
    count BIGINT
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    _now INTEGER := EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER;
BEGIN
    RETURN QUERY
        SELECT COUNT(*)::BIGINT
          FROM auction_listing al
         WHERE al.seller_char_id = _seller_cid
           AND al.state          = 0
           AND al.expires_at     > _now;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_countactiveauctions(INTEGER);
-- +goose StatementEnd
