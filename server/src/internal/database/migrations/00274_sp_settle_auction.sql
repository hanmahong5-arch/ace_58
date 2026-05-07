-- AionCore 5.8 — Auction House (lib/auction.lua hookup) batch 27 / 6 of 7.
--
-- LL: lib/auction.lua hookup, 不替换 NCSoft 历史 aion_addauction 系列
-- (NCSoft 没有 SettleAuction 这个 SP — NCSoft house auction 在 C++ 端编排
--  state machine；doc/migration/procedures/patches/s18_aion_settleauction.sql
--  是先期 patch，绑死了 user_auction 表，本 SP 重写绑新表 auction_listing。
--  patches 文件未被 //go:embed 引用，仅作设计文档；本 SP 才是真正落地)。
--
-- 职责：到期结算的 *atomic* 终态化。被 jobq KindAuctionExpire 工作器（asynq）
-- 调用 — 与 packet handler 完全异步，借用 LuaInvoker 的 pooled VM。
--
-- 流程：
--   1) FOR UPDATE SKIP LOCKED 锁 listing — 双 worker 并发安全
--   2) 校验 state（已 99 → idempotent return code 2）
--   3) 无买家 (current_bidder_cid==0)：goods 邮回卖家（item_nameid 形式），
--      state→99，outcome=0
--   4) 有买家：
--      a. 买家收 *物品邮件* (item_nameid + count)
--      b. 卖家收 *kinah 邮件* (money = current_bid)
--      c. state→99，outcome=1
--
-- Lua 期望签名（scripts/events/on_auction_expire.lua:26 + s18_test.go）：
--   db.call("aion_settleauction", listing_id) → 1 行
--   row = {
--     winner_cid, seller_cid, item_id, item_count, final_bid, outcome_code
--   }
--   outcome_code: 0=no_bids 1=sold 2=already_settled 3=missing
--
-- 邮件路径：通过 aion_mailwritesys_20111227 (00031)。该 SP 的契约（00031:17）：
--   _to_id, _to_name, _from_id, _from_name, _title, _content,
--   _item_id  BIGINT  (user_item.id — 真实物品行 PK，不是 nameid)
--   _item_nameid INTEGER (即 NCSoft item_nameid，对应 lua item_id)
--   _item_amount BIGINT
--   _money    BIGINT
--   _warehouse / _arrive_time / _express_mail
--
-- 我们没有真实 user_item 行（item 在 escrow 阶段被 lua 端 player.spend_item
-- 抽走 — 但 MVP 阶段那个流程还没实装；MVP 期 settle 只发 nameid 形式的
-- "标识邮件"，让玩家看到结果。真正的物品流转留给 Phase S-19+ 实装时
-- 通过 aion_mailwritesys 携带 item_id BIGINT 走 attachment 路径)。
-- → 设计选择：_item_id = 0, _item_nameid = listing.item_id
--   - 0 时 mailwritesys 不动 user_item 表（00031:36 IF _item_id <> 0 THEN）
--   - 收件人靠 mail content + nameid 知道发了什么；后续 Phase 实装真物品时
--     调用 player.add_item(by_nameid) 兑现。
--
-- 终态 sentinel：state=99（与 patches/s18 保持一致 — 99 在 NCSoft enum 之外，
-- 易 grep / 不撞房屋拍卖的 0/1/9/10 取值）。
--
-- 用法：
--   scripts/events/on_auction_expire.lua → asynq KindAuctionExpire 工作器

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settleauction(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _listing_id : 到期 listing
-- 返回 1 行；列名严格匹配 on_auction_expire.lua 与 s18_test.go 期望。
CREATE OR REPLACE FUNCTION aion_settleauction(
    _listing_id BIGINT
) RETURNS TABLE (
    winner_cid   INTEGER,
    seller_cid   INTEGER,
    item_id      BIGINT,
    item_count   BIGINT,
    final_bid    BIGINT,
    outcome_code INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    _row     auction_listing%ROWTYPE;
    _now     INTEGER := EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER;
    _title   TEXT;
    _content TEXT;
    _winner_name VARCHAR(20);
BEGIN
    -- SKIP LOCKED → twin worker 看到空 cursor，落到下方 outcome=2 路径
    SELECT * INTO _row
      FROM auction_listing
     WHERE listing_id = _listing_id
       FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
        -- 区分 "row 不存在" vs "row 被 twin 锁着"：再做一次无锁存在性探测
        IF EXISTS (SELECT 1 FROM auction_listing WHERE listing_id = _listing_id) THEN
            -- twin 在跑，幂等 no-op
            RETURN QUERY SELECT 0, 0, 0::BIGINT, 0::BIGINT, 0::BIGINT, 2;
            RETURN;
        END IF;
        -- 真不存在 — 过期 trigger 但 listing 已被删
        RETURN QUERY SELECT 0, 0, 0::BIGINT, 0::BIGINT, 0::BIGINT, 3;
        RETURN;
    END IF;

    -- 已是终态 99 → 幂等 ok（asynq 重试 / 双 worker 都打到这）
    IF _row.state = 99 THEN
        RETURN QUERY SELECT
            _row.current_bidder_cid,
            _row.seller_char_id,
            _row.item_id::BIGINT,
            _row.item_count::BIGINT,
            _row.current_bid,
            2;
        RETURN;
    END IF;

    -- 已撤销 (state=1) — 不应该走到这（cancel 时 listing 已退出 active），
    -- 但 asynq 可能还有 stale trigger，按 already 处理
    IF _row.state = 1 THEN
        RETURN QUERY SELECT
            0, _row.seller_char_id,
            _row.item_id::BIGINT,
            _row.item_count::BIGINT,
            0::BIGINT, 2;
        RETURN;
    END IF;

    -- ──────────────── 真正的 settle 路径 ────────────────

    IF _row.current_bidder_cid = 0 THEN
        -- 无人出价 — 物品邮回卖家
        _title   := 'Auction Expired';
        _content := 'Your auction listing expired with no bidders. The item is returned.';
        PERFORM aion_mailwritesys_20111227(
            _row.seller_char_id,
            _row.seller_name::TEXT,
            0,
            'System',
            _title,
            _content,
            0::BIGINT,                   -- item_id (0 → 不动 user_item 表)
            _row.item_id,                -- item_nameid
            _row.item_count::BIGINT,     -- item_amount
            0::BIGINT,                   -- money
            0,                           -- warehouse
            _now,                        -- arrive_time
            0                            -- express_mail
        );

        UPDATE auction_listing
           SET state = 99
         WHERE listing_id = _listing_id;

        RETURN QUERY SELECT
            0,
            _row.seller_char_id,
            _row.item_id::BIGINT,
            _row.item_count::BIGINT,
            0::BIGINT,
            0;
        RETURN;
    END IF;

    -- 有买家 — 物品给买家，金钱给卖家
    SELECT SUBSTR(COALESCE(ud.name, ''), 1, 20)
      INTO _winner_name
      FROM user_data ud
     WHERE ud.char_id = _row.current_bidder_cid
       AND ud.delete_date = 0;
    IF _winner_name IS NULL THEN
        _winner_name := '?';
    END IF;

    -- mail 1：买家收物品
    _title   := 'Auction Won';
    _content := 'Congratulations! You have won the auction. The item is attached.';
    PERFORM aion_mailwritesys_20111227(
        _row.current_bidder_cid,
        _winner_name::TEXT,
        0,
        'System',
        _title,
        _content,
        0::BIGINT,
        _row.item_id,
        _row.item_count::BIGINT,
        0::BIGINT,
        0, _now, 0
    );

    -- mail 2：卖家收金钱
    _title   := 'Auction Sold';
    _content := 'Your auction has been sold. Sale proceeds are attached.';
    PERFORM aion_mailwritesys_20111227(
        _row.seller_char_id,
        _row.seller_name::TEXT,
        0,
        'System',
        _title,
        _content,
        0::BIGINT,
        0,
        0::BIGINT,
        _row.current_bid,            -- money
        0, _now, 0
    );

    UPDATE auction_listing
       SET state = 99
     WHERE listing_id = _listing_id;

    RETURN QUERY SELECT
        _row.current_bidder_cid,
        _row.seller_char_id,
        _row.item_id::BIGINT,
        _row.item_count::BIGINT,
        _row.current_bid,
        1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settleauction(BIGINT);
-- +goose StatementEnd
