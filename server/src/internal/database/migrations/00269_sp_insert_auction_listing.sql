-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 1 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 00066-00071 / 00224-00228 / 00259-00260 服务的是房屋拍卖；本批
--  是 lua scripts/lib/auction.lua 设计的 *物品拍卖行* 闭环 — 两套并存)。
--
-- 本文件职责（atomic group 第一块 — 落表 + 上架 SP）：
--   1) 创建 auction_listing 表 — 主表，listing_id BIGSERIAL，state 三态枚举。
--   2) 创建 aion_insertauctionlisting() — Lua auction.register 的写入端。
--
-- Lua 期望签名（scripts/lib/auction.lua:109）：
--   db.call("aion_InsertAuctionListing",
--           cid, item_id, count, min_bid, buy_now, expires_at)
--   → rows[1].listing_id 或 .id  (BIGINT)
--
-- 字段对位说明：
--   cid          INTEGER   seller char_id (entity.get_stat 的 char_id)
--   item_id      INTEGER   物品 nameid (NCSoft item_nameid)
--   count        INTEGER   物品数量
--   min_bid      BIGINT    起拍价 (kinah)
--   buy_now      BIGINT    一口价 (0 = 无)
--   expires_at   INTEGER   epoch 秒 (lua os.time() + duration*3600)
--
-- 表结构设计：
--   listing_id          BIGSERIAL PK   — 由 PG 序列生成，无冲突
--   seller_char_id      INTEGER         — 卖家 char_id（user_data.char_id）
--   seller_name         VARCHAR(20)     — 缓存卖家名（搜索/邮件用，避免 N+1 join）
--   item_id             INTEGER         — 物品 nameid
--   item_count          INTEGER
--   min_bid / buy_now   BIGINT          — 价格
--   current_bid         BIGINT  DEFAULT 0  — 当前最高出价
--   current_bidder_cid  INTEGER DEFAULT 0  — 当前最高出价人
--   expires_at          INTEGER NOT NULL   — epoch 秒（INT 足够 — 5.8 server
--                       生命周期内不会 2038，且和 user_grace.starttime 一致）
--   state               SMALLINT NOT NULL DEFAULT 0
--                       0 = active   (默认上架后)
--                       1 = cancelled (cancel 后)
--                       99 = settled (settleauction 终态，与 patches/s18 对齐)
--   created_at          INTEGER NOT NULL  — epoch 秒，审计用
--
-- 索引策略：
--   - active 列表搜索 (item_id 过滤)：(item_id, state) WHERE state=0
--   - 卖家 active 配额计数：(seller_char_id, state) WHERE state=0
--   - 到期扫描备用：(expires_at) WHERE state=0
--
-- 用法：
--   scripts/lib/auction.lua  → auction.register

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- auction_listing — 物品拍卖主表（首次引入）。
-- 与 NCSoft user_auction (00066) 的房屋拍卖完全分离。
-- ====================================================================
CREATE TABLE IF NOT EXISTS auction_listing (
    listing_id          BIGSERIAL    PRIMARY KEY,
    seller_char_id      INTEGER      NOT NULL,
    seller_name         VARCHAR(20)  NOT NULL DEFAULT '',
    item_id             INTEGER      NOT NULL,
    item_count          INTEGER      NOT NULL DEFAULT 1,
    min_bid             BIGINT       NOT NULL,
    buy_now             BIGINT       NOT NULL DEFAULT 0,
    current_bid         BIGINT       NOT NULL DEFAULT 0,
    current_bidder_cid  INTEGER      NOT NULL DEFAULT 0,
    expires_at          INTEGER      NOT NULL,
    state               SMALLINT     NOT NULL DEFAULT 0,
    created_at          INTEGER      NOT NULL
);
-- +goose StatementEnd

-- +goose StatementBegin
-- 搜索热路径：item_id 过滤 + state=0
CREATE INDEX IF NOT EXISTS idx_auction_listing_search
    ON auction_listing (item_id, state)
    WHERE state = 0;
-- +goose StatementEnd

-- +goose StatementBegin
-- 卖家 active 配额计数（auction.MAX_ACTIVE_PER_USER = 15）
CREATE INDEX IF NOT EXISTS idx_auction_listing_seller_active
    ON auction_listing (seller_char_id)
    WHERE state = 0;
-- +goose StatementEnd

-- +goose StatementBegin
-- 到期扫描备用（asynq 失效时的 SP-side sweep 安全网）
CREATE INDEX IF NOT EXISTS idx_auction_listing_expires
    ON auction_listing (expires_at)
    WHERE state = 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_insertauctionlisting(
    INTEGER, INTEGER, INTEGER, BIGINT, BIGINT, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
-- _seller_cid    : seller char_id
-- _item_id       : 物品 nameid
-- _item_count    : 数量
-- _min_bid       : 起拍价
-- _buy_now       : 一口价 (0 = 无)
-- _expires_at    : epoch 秒 (Lua os.time() + duration*3600)
--
-- 返回 1 行 { listing_id BIGINT }（与 Lua 期望 rows[1].listing_id 对齐）。
-- 卖家名通过 user_data join 解析；找不到（孤儿测试 cid）则空串 '?'，
-- 不阻塞插入 — 测试 / GM 也能上架。
CREATE OR REPLACE FUNCTION aion_insertauctionlisting(
    _seller_cid    INTEGER,
    _item_id       INTEGER,
    _item_count    INTEGER,
    _min_bid       BIGINT,
    _buy_now       BIGINT,
    _expires_at    INTEGER
) RETURNS TABLE (
    listing_id BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
    _seller_name VARCHAR(20);
    _new_id      BIGINT;
    _now         INTEGER := EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER;
BEGIN
    -- 解析卖家名（不 join 入主表 — 主表是热路径，缓存名走单独列）。
    SELECT SUBSTR(COALESCE(ud.name, ''), 1, 20)
      INTO _seller_name
      FROM user_data ud
     WHERE ud.char_id = _seller_cid
       AND ud.delete_date = 0;
    IF _seller_name IS NULL THEN
        _seller_name := '?';
    END IF;

    INSERT INTO auction_listing (
        seller_char_id, seller_name,
        item_id, item_count,
        min_bid, buy_now,
        current_bid, current_bidder_cid,
        expires_at, state, created_at
    ) VALUES (
        _seller_cid, _seller_name,
        _item_id, _item_count,
        _min_bid, _buy_now,
        0, 0,
        _expires_at, 0, _now
    )
    RETURNING auction_listing.listing_id INTO _new_id;

    RETURN QUERY SELECT _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_insertauctionlisting(
    INTEGER, INTEGER, INTEGER, BIGINT, BIGINT, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_auction_listing_expires;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_auction_listing_seller_active;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_auction_listing_search;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS auction_listing;
-- +goose StatementEnd
