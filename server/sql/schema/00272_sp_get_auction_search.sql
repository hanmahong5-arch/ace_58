-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 4 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 历史 aion_GetAuctionList_110628 服务的是房屋拍卖；本 SP 是物品
--  拍卖搜索，分页 / 价格区间 / item_id 过滤)。
--
-- 职责：支持客户端 CM_AUCTION_SEARCH (0xC9) 的列表分页查询。
--
-- Lua 期望签名（scripts/lib/auction.lua:152）：
--   db.call("aion_GetAuctionSearch",
--           item_id_filter, min_price, max_price, page)
--   → 多行
--
-- 入参约定：
--   _item_id_filter  INTEGER  : 0 = 不过滤，>0 = 严格匹配 item_id
--   _min_price       BIGINT   : 0 = 不过滤价格下界（按 min_bid 比较）
--   _max_price       BIGINT   : 0 = 不过滤价格上界
--   _page            INTEGER  : 0-based 页号（cm_auction_search.lua:8）
--
-- 分页：每页 20 条（NCSoft house auction list_110628 用 10/20 不一，本 SP
-- 选 20 — 一屏典型容量；客户端 SM_AUCTION_SEARCH_RESULT 0xCD 没有页大小
-- 字段，所以 SP 端硬定）。
--
-- 排序：min_bid ASC（便宜优先），listing_id DESC tiebreak（新上架优先）。
-- 这是物品拍卖最常见 UX；如客户端要求其他排序，SP 升级时新增 _order_by
-- 入参，保持前几位入参兼容。
--
-- 过滤：state=0（active）+ expires_at > now（未到期）。NCSoft 历史 SP 不做
-- expires 过滤（它信任过期 sweep 跑完了）；本 SP 防御性过滤是因为 asynq
-- 可能 disabled 或 lag — 用户搜不到过期但未结算的 listing 比看到强。
--
-- 用法：
--   scripts/lib/auction.lua → auction.search

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionsearch(INTEGER, BIGINT, BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- 列名与 cm_auction_search.lua 的 row.xxx 严格对位 — 出包 0xCD 直接用。
CREATE OR REPLACE FUNCTION aion_getauctionsearch(
    _item_id_filter INTEGER,
    _min_price      BIGINT,
    _max_price      BIGINT,
    _page           INTEGER
) RETURNS TABLE (
    listing_id  BIGINT,
    item_id     INTEGER,
    item_count  INTEGER,
    min_bid     BIGINT,
    current_bid BIGINT,
    buy_now     BIGINT,
    expires_at  INTEGER,
    seller_name VARCHAR(20)
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    _page_size CONSTANT INTEGER := 20;
    _offset INTEGER;
    _now    INTEGER := EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER;
BEGIN
    -- 防御负页号
    IF _page < 0 THEN
        _page := 0;
    END IF;
    _offset := _page * _page_size;

    RETURN QUERY
        SELECT  al.listing_id,
                al.item_id,
                al.item_count,
                al.min_bid,
                al.current_bid,
                al.buy_now,
                al.expires_at,
                al.seller_name
          FROM auction_listing al
         WHERE al.state      = 0
           AND al.expires_at > _now
           AND (_item_id_filter = 0 OR al.item_id = _item_id_filter)
           AND (_min_price      = 0 OR al.min_bid >= _min_price)
           AND (_max_price      = 0 OR al.min_bid <= _max_price)
         ORDER BY al.min_bid ASC, al.listing_id DESC
         LIMIT _page_size OFFSET _offset;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionsearch(INTEGER, BIGINT, BIGINT, INTEGER);
-- +goose StatementEnd
