// Package database — integration test for the auction closure SP set
// (00269..00275). This is the *7-SP atomic batch* that unlocks
// scripts/lib/auction.lua's CM_AUCTION_REGISTER / SEARCH / BID / CANCEL
// chain plus the on_auction_expire settlement worker.
//
// Sub-tests:
//
//  1. RegisterListing       — aion_insertauctionlisting persists & returns id
//  2. CountActiveAuctions   — aion_countactiveauctions reflects state=0 rows
//  3. SearchFilters         — aion_getauctionsearch honours item/price/page
//  4. GetById               — aion_getauctionbyid returns single-row payload
//  5. BidOnceAndOverbid     — aion_insertauctionbid raises current_bid + history
//  6. CancelNoBids          — aion_cancelauction flips state to 1 (cancelled)
//  7. SettleAuction         — aion_settleauction terminal-states + outcome codes
//
// char_id band: 9_700_001..9_700_099 (R27/auction).
//
// Skips with a clear message when AION_TEST_PG_* tuple is missing.
package database

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
)

// ───────────────────────────── id band ─────────────────────────────────

const (
	cidAucSellerA = 9700001 // 主卖家 A
	cidAucSellerB = 9700002 // 主卖家 B (search 过滤辅助)
	cidAucBidder  = 9700010 // 主出价人
	cidAucBidder2 = 9700011 // 抢价覆盖出价人
	cidAucEmpty   = 9700020 // count=0 baseline 测试用（不上架）
)

// auctionCleanup wipes every row in the R27 char band from auction_listing,
// auction_bid, user_mail, user_data — order matters for FK-free schema but
// keeps deletes deterministic across re-runs.
func auctionCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM auction_bid
		   WHERE listing_id IN (
		       SELECT listing_id FROM auction_listing
		        WHERE seller_char_id BETWEEN 9700001 AND 9700099
		   )`); err != nil {
		t.Fatalf("cleanup auction_bid: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM auction_listing
		   WHERE seller_char_id BETWEEN 9700001 AND 9700099`); err != nil {
		t.Fatalf("cleanup auction_listing: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_mail
		   WHERE to_id BETWEEN 9700001 AND 9700099
		      OR from_id BETWEEN 9700001 AND 9700099`); err != nil {
		t.Fatalf("cleanup user_mail: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data
		   WHERE char_id BETWEEN 9700001 AND 9700099`); err != nil {
		t.Fatalf("cleanup user_data: %v", err)
	}
}

// auctionSeedChars 注入 4 个测试角色 — settle SP 通过 user_data 解析
// seller_name / winner_name；空 user_data 行会让 SP 走默认 '?' 字符串。
func auctionSeedChars(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	chars := []struct {
		id   int
		name string
	}{
		{cidAucSellerA, "AucSeller"},
		{cidAucSellerB, "AucSellerB"},
		{cidAucBidder, "AucBidder"},
		{cidAucBidder2, "AucBidder2"},
	}
	for _, c := range chars {
		if _, err := p.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			c.id, c.name, "auc_"+c.name); err != nil {
			t.Fatalf("seed user_data %s: %v", c.name, err)
		}
	}
}

// TestSP_AuctionClosure 跑 7 个 sub-test，串成一条完整的拍卖闭环：
// register → search → bid → outbid → cancel(独立 listing) → settle 多分支。
func TestSP_AuctionClosure(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	auctionCleanup(t, ctx, pool)
	t.Cleanup(func() { auctionCleanup(t, context.Background(), pool) })
	auctionSeedChars(t, ctx, pool)

	// Future-anchored expires_at（远超测试时间，确保未到期）
	// + past-anchored expires_at（用于 settle 路径）。
	// 注意：00269 auction_listing.expires_at 是 INTEGER（int4，max=2147483647 ≈ 2038-01）。
	// 之前用 4_900_000_000（2125 年）会触发 pgx 'int4 overflow'。改用 2_100_000_000
	// (2036-07) — 仍然远超 2026 测试时点，但落在 int4 域内，匹配 SP 设计。
	const (
		futureExpiry = 2_100_000_000 // 2036-07
		pastExpiry   = 1_000_000_000 // 2001 年
	)

	// 共享变量：register 出来的 id，下面 sub-test 链式消费
	var (
		listingMain  int64 // 主测试 listing — search/bid/getById 用
		listingNoBid int64 // cancel 用，永不出价
		listingPast  int64 // settle no_bids 路径
		listingSold  int64 // settle sold 路径
	)

	// ──────────────────────────────────────────────────────────────────
	// 1. RegisterListing — 上架成功 + 字段持久化 + 返回 listing_id
	// ──────────────────────────────────────────────────────────────────
	t.Run("RegisterListing", func(t *testing.T) {
		if err := pool.CallSPRow(ctx, "aion_insertauctionlisting",
			int(cidAucSellerA), int(110000001), int(2),
			int64(50000), int64(200000), int(futureExpiry),
		).Scan(&listingMain); err != nil {
			t.Fatalf("CallSPRow register: %v", err)
		}
		if listingMain <= 0 {
			t.Fatalf("listing_id: got %d, want > 0", listingMain)
		}

		var (
			seller   int
			itemID   int
			count    int
			minBid   int64
			buyNow   int64
			curBid   int64
			expires  int
			state    int16
			sellName string
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT seller_char_id, item_id, item_count, min_bid, buy_now,
			        current_bid, expires_at, state, seller_name
			   FROM auction_listing WHERE listing_id=$1`, listingMain,
		).Scan(&seller, &itemID, &count, &minBid, &buyNow,
			&curBid, &expires, &state, &sellName); err != nil {
			t.Fatalf("verify register: %v", err)
		}
		if seller != cidAucSellerA || itemID != 110000001 || count != 2 ||
			minBid != 50000 || buyNow != 200000 || curBid != 0 ||
			expires != futureExpiry || state != 0 {
			t.Fatalf("register payload: seller=%d item=%d count=%d min=%d buy=%d cur=%d exp=%d state=%d",
				seller, itemID, count, minBid, buyNow, curBid, expires, state)
		}
		if sellName != "AucSeller" {
			t.Fatalf("seller_name: got %q, want AucSeller", sellName)
		}

		// 同时上架一个 no-bid listing 与三个 settle 测试 listings
		if err := pool.CallSPRow(ctx, "aion_insertauctionlisting",
			int(cidAucSellerA), int(110000002), int(1),
			int64(10000), int64(0), int(futureExpiry),
		).Scan(&listingNoBid); err != nil {
			t.Fatalf("register noBid: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_insertauctionlisting",
			int(cidAucSellerA), int(110000003), int(1),
			int64(15000), int64(0), int(pastExpiry),
		).Scan(&listingPast); err != nil {
			t.Fatalf("register past: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_insertauctionlisting",
			int(cidAucSellerA), int(110000004), int(3),
			int64(20000), int64(0), int(pastExpiry),
		).Scan(&listingSold); err != nil {
			t.Fatalf("register sold-base: %v", err)
		}
	})

	// ──────────────────────────────────────────────────────────────────
	// 2. CountActiveAuctions — 卖家 A 现在 4 active；卖家 B 0
	//    注：listingPast / listingSold 的 expires_at < now → 不算 active
	//    （SP 过滤 expires_at>now），所以只有 listingMain + listingNoBid
	//    = 2 active for cidAucSellerA
	// ──────────────────────────────────────────────────────────────────
	t.Run("CountActiveAuctions", func(t *testing.T) {
		var n int64
		if err := pool.CallSPRow(ctx, "aion_countactiveauctions",
			int(cidAucSellerA)).Scan(&n); err != nil {
			t.Fatalf("CallSPRow count: %v", err)
		}
		if n != 2 {
			t.Fatalf("count active for sellerA: got %d, want 2 "+
				"(future-expiry listingMain + listingNoBid; "+
				"past-expiry pair excluded)", n)
		}
		if err := pool.CallSPRow(ctx, "aion_countactiveauctions",
			int(cidAucSellerB)).Scan(&n); err != nil {
			t.Fatalf("CallSPRow count B: %v", err)
		}
		if n != 0 {
			t.Fatalf("count active for sellerB: got %d, want 0", n)
		}
	})

	// ──────────────────────────────────────────────────────────────────
	// 3. SearchFilters — item_id 严格匹配 + 价格区间 + page=0 找到 listingMain
	// ──────────────────────────────────────────────────────────────────
	t.Run("SearchFilters", func(t *testing.T) {
		// 严格 item_id 过滤，期望命中 listingMain 那条
		rows, err := pool.CallSP(ctx, "aion_getauctionsearch",
			int(110000001), int64(0), int64(0), int(0))
		if err != nil {
			t.Fatalf("CallSP search: %v", err)
		}
		var found bool
		for rows.Next() {
			var (
				id       int64
				itemID   int
				count    int
				minBid   int64
				curBid   int64
				buyNow   int64
				expires  int
				sellName string
			)
			if err := rows.Scan(&id, &itemID, &count, &minBid, &curBid,
				&buyNow, &expires, &sellName); err != nil {
				rows.Close()
				t.Fatalf("scan row: %v", err)
			}
			if id == listingMain {
				found = true
				if itemID != 110000001 || count != 2 || minBid != 50000 ||
					buyNow != 200000 || expires != futureExpiry ||
					sellName != "AucSeller" {
					t.Errorf("search row payload mismatch: id=%d item=%d count=%d min=%d buy=%d exp=%d sell=%s",
						id, itemID, count, minBid, buyNow, expires, sellName)
				}
			}
		}
		rows.Close()
		if !found {
			t.Fatalf("search by item_id=110000001: listingMain %d not found",
				listingMain)
		}

		// 价格区间过滤：min_price 6w → listingMain (5w) 应被排除
		rows, err = pool.CallSP(ctx, "aion_getauctionsearch",
			int(110000001), int64(60000), int64(0), int(0))
		if err != nil {
			t.Fatalf("CallSP search filter: %v", err)
		}
		var n int
		for rows.Next() {
			n++
		}
		rows.Close()
		if n != 0 {
			t.Fatalf("search min_price=60000 filter: got %d rows, want 0", n)
		}
	})

	// ──────────────────────────────────────────────────────────────────
	// 4. GetById — listingMain 单条读取，列名匹配 Lua 期望
	// ──────────────────────────────────────────────────────────────────
	t.Run("GetById", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getauctionbyid", listingMain)
		if err != nil {
			t.Fatalf("CallSP getById: %v", err)
		}
		defer rows.Close()
		if !rows.Next() {
			t.Fatalf("getById: no row for listing %d", listingMain)
		}
		var (
			id       int64
			seller   int
			sellName string
			itemID   int
			count    int
			minBid   int64
			buyNow   int64
			curBid   int64
			curBdr   int
			expires  int
			state    int16
		)
		if err := rows.Scan(&id, &seller, &sellName, &itemID, &count,
			&minBid, &buyNow, &curBid, &curBdr, &expires, &state); err != nil {
			t.Fatalf("scan getById: %v", err)
		}
		if id != listingMain || seller != cidAucSellerA || curBid != 0 ||
			expires != futureExpiry || state != 0 {
			t.Fatalf("getById payload: id=%d seller=%d cur=%d exp=%d state=%d",
				id, seller, curBid, expires, state)
		}
	})

	// ──────────────────────────────────────────────────────────────────
	// 5. BidOnceAndOverbid — 首次出价 50000 (= min_bid)；overbid 60000；
	//                       too-low 55000 应被 RAISE
	// ──────────────────────────────────────────────────────────────────
	t.Run("BidOnceAndOverbid", func(t *testing.T) {
		var bidID int64
		if err := pool.CallSPRow(ctx, "aion_insertauctionbid",
			listingMain, int(cidAucBidder), int64(50000)).Scan(&bidID); err != nil {
			t.Fatalf("first bid: %v", err)
		}
		if bidID <= 0 {
			t.Fatalf("first bid_id: got %d, want > 0", bidID)
		}

		// listingMain 应反映 current_bid=50000, current_bidder=cidAucBidder
		var (
			cur    int64
			curBdr int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT current_bid, current_bidder_cid
			   FROM auction_listing WHERE listing_id=$1`, listingMain,
		).Scan(&cur, &curBdr); err != nil {
			t.Fatalf("verify first bid: %v", err)
		}
		if cur != 50000 || curBdr != cidAucBidder {
			t.Fatalf("after first bid: current=%d bidder=%d, want 50000/%d",
				cur, curBdr, cidAucBidder)
		}

		// Overbid 60000 by bidder2 — 必须 succeed
		var bidID2 int64
		if err := pool.CallSPRow(ctx, "aion_insertauctionbid",
			listingMain, int(cidAucBidder2), int64(60000)).Scan(&bidID2); err != nil {
			t.Fatalf("overbid: %v", err)
		}
		if bidID2 <= bidID {
			t.Fatalf("overbid bid_id non-monotonic: %d vs %d", bidID2, bidID)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT current_bid, current_bidder_cid
			   FROM auction_listing WHERE listing_id=$1`, listingMain,
		).Scan(&cur, &curBdr); err != nil {
			t.Fatalf("verify overbid: %v", err)
		}
		if cur != 60000 || curBdr != cidAucBidder2 {
			t.Fatalf("after overbid: current=%d bidder=%d, want 60000/%d",
				cur, curBdr, cidAucBidder2)
		}

		// Too-low 55000 from bidder — must RAISE
		var dummy int64
		err := pool.CallSPRow(ctx, "aion_insertauctionbid",
			listingMain, int(cidAucBidder), int64(55000)).Scan(&dummy)
		if err == nil {
			t.Fatalf("too-low bid 55000 must RAISE; got nil err")
		}
		// pgx 把 plpgsql RAISE 包成 pgconn.PgError。注意：Severity 受 PG 客户端
		// 区域影响（zh_CN.UTF-8 → "错误"），SeverityUnlocalized 是固定 ASCII 协议字段。
		if pgErr, ok := err.(*pgconn.PgError); ok {
			if pgErr.SeverityUnlocalized != "ERROR" {
				t.Errorf("too-low bid: expected SeverityUnlocalized=ERROR, got %s (localized=%s)",
					pgErr.SeverityUnlocalized, pgErr.Severity)
			}
		}

		// 出价历史应有 2 行（首次 + overbid，55000 被拒不入库）
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM auction_bid WHERE listing_id=$1`,
			listingMain).Scan(&n); err != nil {
			t.Fatalf("count bid history: %v", err)
		}
		if n != 2 {
			t.Fatalf("bid history count: got %d, want 2", n)
		}
	})

	// ──────────────────────────────────────────────────────────────────
	// 6. CancelNoBids — listingNoBid 无人出价，cancel 应翻 state→1；
	//    再 cancel 同一条应 RAISE（state 不再 =0）；
	//    listingMain 已有 bid，cancel 应 RAISE。
	// ──────────────────────────────────────────────────────────────────
	t.Run("CancelNoBids", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_cancelauction",
			listingNoBid, int(cidAucSellerA)); err != nil {
			t.Fatalf("cancel noBid: %v", err)
		}
		var state int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM auction_listing WHERE listing_id=$1`,
			listingNoBid).Scan(&state); err != nil {
			t.Fatalf("verify cancel: %v", err)
		}
		if state != 1 {
			t.Fatalf("state after cancel: got %d, want 1", state)
		}

		// 二次 cancel 同一 listing — RAISE
		if err := pool.CallSPExec(ctx, "aion_cancelauction",
			listingNoBid, int(cidAucSellerA)); err == nil {
			t.Fatalf("double-cancel must RAISE; got nil err")
		}

		// listingMain 已有出价 — cancel 必 RAISE (has_bids)
		if err := pool.CallSPExec(ctx, "aion_cancelauction",
			listingMain, int(cidAucSellerA)); err == nil {
			t.Fatalf("cancel listing-with-bid must RAISE; got nil err")
		}

		// 错误所有人 cancel — RAISE
		if err := pool.CallSPExec(ctx, "aion_cancelauction",
			listingPast, int(cidAucBidder)); err == nil {
			t.Fatalf("cancel by non-owner must RAISE; got nil err")
		}
	})

	// ──────────────────────────────────────────────────────────────────
	// 7. SettleAuction — 4 路径：
	//    a. listingPast (expires=过去, no bid) → outcome=0，邮件回卖家
	//    b. listingSold (有买家) → outcome=1，2 封邮件
	//    c. settle 已 settled → outcome=2 (idempotent)
	//    d. settle 不存在 listing → outcome=3
	// ──────────────────────────────────────────────────────────────────
	t.Run("SettleAuction", func(t *testing.T) {
		// 给 listingSold 注一笔出价让它有 winner
		var dummy int64
		if _, err := pool.Inner().Exec(ctx,
			`UPDATE auction_listing
			    SET current_bid=80000, current_bidder_cid=$1
			  WHERE listing_id=$2`,
			cidAucBidder, listingSold); err != nil {
			t.Fatalf("seed sold winner: %v", err)
		}
		_ = dummy

		// 7a. no-bids settle
		rows, err := pool.CallSP(ctx, "aion_settleauction", listingPast)
		if err != nil {
			t.Fatalf("settle past: %v", err)
		}
		if !rows.Next() {
			rows.Close()
			t.Fatalf("settle past: no row")
		}
		var (
			winnerCID int
			sellerCID int
			itemID    int64
			itemCnt   int64
			finalBid  int64
			outcome   int
		)
		if err := rows.Scan(&winnerCID, &sellerCID, &itemID,
			&itemCnt, &finalBid, &outcome); err != nil {
			rows.Close()
			t.Fatalf("scan settle past: %v", err)
		}
		rows.Close()
		if outcome != 0 || winnerCID != 0 || sellerCID != cidAucSellerA ||
			finalBid != 0 {
			t.Fatalf("settle past payload: w=%d s=%d bid=%d outcome=%d, want 0/%d/0/0",
				winnerCID, sellerCID, finalBid, outcome, cidAucSellerA)
		}

		// state 翻 99
		var state int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM auction_listing WHERE listing_id=$1`,
			listingPast).Scan(&state); err != nil {
			t.Fatalf("verify settled state: %v", err)
		}
		if state != 99 {
			t.Fatalf("settled state: got %d, want 99", state)
		}

		// 7b. sold path
		rows, err = pool.CallSP(ctx, "aion_settleauction", listingSold)
		if err != nil {
			t.Fatalf("settle sold: %v", err)
		}
		if !rows.Next() {
			rows.Close()
			t.Fatalf("settle sold: no row")
		}
		if err := rows.Scan(&winnerCID, &sellerCID, &itemID,
			&itemCnt, &finalBid, &outcome); err != nil {
			rows.Close()
			t.Fatalf("scan settle sold: %v", err)
		}
		rows.Close()
		if outcome != 1 || winnerCID != cidAucBidder ||
			sellerCID != cidAucSellerA || finalBid != 80000 {
			t.Fatalf("settle sold payload: w=%d s=%d bid=%d outcome=%d, want 1/%d/%d/80000",
				winnerCID, sellerCID, finalBid, outcome,
				cidAucBidder, cidAucSellerA)
		}

		// 邮件应该有 3 封：listingPast 回卖家 1 + listingSold 买家1 + 卖家1
		var mailCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_mail
			   WHERE to_id BETWEEN 9700001 AND 9700099`).Scan(&mailCnt); err != nil {
			t.Fatalf("count mails: %v", err)
		}
		if mailCnt != 3 {
			t.Fatalf("mail count: got %d, want 3 (1 expired return + 1 buyer + 1 seller)",
				mailCnt)
		}

		// 7c. idempotent re-settle 同一条 listingSold
		rows, err = pool.CallSP(ctx, "aion_settleauction", listingSold)
		if err != nil {
			t.Fatalf("re-settle sold: %v", err)
		}
		if !rows.Next() {
			rows.Close()
			t.Fatalf("re-settle: no row")
		}
		if err := rows.Scan(&winnerCID, &sellerCID, &itemID,
			&itemCnt, &finalBid, &outcome); err != nil {
			rows.Close()
			t.Fatalf("scan re-settle: %v", err)
		}
		rows.Close()
		if outcome != 2 {
			t.Fatalf("re-settle outcome: got %d, want 2 (already_settled)",
				outcome)
		}

		// 7d. settle 不存在的 listing
		rows, err = pool.CallSP(ctx, "aion_settleauction", int64(99999999))
		if err != nil {
			t.Fatalf("settle missing: %v", err)
		}
		if !rows.Next() {
			rows.Close()
			t.Fatalf("settle missing: no row")
		}
		if err := rows.Scan(&winnerCID, &sellerCID, &itemID,
			&itemCnt, &finalBid, &outcome); err != nil {
			rows.Close()
			t.Fatalf("scan settle missing: %v", err)
		}
		rows.Close()
		if outcome != 3 {
			t.Fatalf("settle missing outcome: got %d, want 3", outcome)
		}
	})
}
