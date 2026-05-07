// Package database — integration test for aion_AddAuctionFilterList.
//
// INSERT-IF-NOT-EXISTS into user_auctionfilter, EXISTS guard on goodsID
// alone (NOT (type, goodsID)). Returns rows-affected: 0 = blocked by
// EXISTS, 1 = inserted. user_auctionfilter is shared across all chars
// (no owner column); the band-cleanup uses goodsID range, not char_id.
//
// Test matrix:
//   - first call inserts (1 row), payload round-trips
//   - second call with same goodsID (any type) blocked → 0 rows
//   - distinct goodsIDs coexist
//   - bug-for-bug: same goodsID under DIFFERENT type also blocked
//
// goodsID band: 95_60_001..95_60_099 (R18 batch — auction-filter / grace).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	goodsAfA   = 95600101 // first insert
	goodsAfB   = 95600102 // distinct goods, must coexist
	goodsAfDup = 95600103 // exercises EXISTS-on-goodsID-only pin
)

func addAuctionFilterCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_auctionfilter WHERE goodsID BETWEEN 95600101 AND 95600199`); err != nil {
		t.Fatalf("addAuctionFilterCleanup: %v", err)
	}
}

func TestAddAuctionFilterList(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	addAuctionFilterCleanup(t, ctx, pool)
	t.Cleanup(func() { addAuctionFilterCleanup(t, context.Background(), pool) })

	t.Run("first call inserts, payload round-trips", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addauctionfilterlist",
			int(1), int(goodsAfA)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first affected: got %d, want 1", affected)
		}

		var (
			gType   int
			gGoods  int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT type, goodsID FROM user_auctionfilter WHERE goodsID=$1`,
			goodsAfA).Scan(&gType, &gGoods); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if gType != 1 || gGoods != goodsAfA {
			t.Fatalf("payload: type=%d goodsID=%d, want 1/%d", gType, gGoods, goodsAfA)
		}
	})

	t.Run("second call same goodsID same type blocked → 0 rows", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addauctionfilterlist",
			int(1), int(goodsAfA)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow dup-same: %v", err)
		}
		if affected != 0 {
			t.Fatalf("dup-same affected: got %d, want 0", affected)
		}

		// Confirm count stayed at 1.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_auctionfilter WHERE goodsID=$1`,
			goodsAfA).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("dup-same count: got %d, want 1", n)
		}
	})

	t.Run("distinct goodsIDs coexist", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addauctionfilterlist",
			int(2), int(goodsAfB)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_auctionfilter WHERE goodsID IN ($1, $2)`,
			goodsAfA, goodsAfB).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 2 {
			t.Fatalf("after B insert: got %d rows, want 2", n)
		}
	})

	t.Run("bug-for-bug: same goodsID under different type also blocked", func(t *testing.T) {
		// Pin: NCSoft EXISTS check is goodsID-only. Inserting goodsAfDup
		// under type=1 first, then under type=2 must short-circuit (0).
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addauctionfilterlist",
			int(1), int(goodsAfDup)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow dup1: %v", err)
		}
		if affected != 1 {
			t.Fatalf("dup1 affected: got %d, want 1", affected)
		}

		// Same goodsID, different type — must be blocked, NOT a unique-violation.
		if err := pool.CallSPRow(ctx, "aion_addauctionfilterlist",
			int(2), int(goodsAfDup)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow dup2: %v", err)
		}
		if affected != 0 {
			t.Fatalf("dup2 affected: got %d, want 0 (NCSoft EXISTS-on-goodsID pin)", affected)
		}

		// Confirm only 1 row exists for goodsAfDup, with the original type=1.
		var (
			n     int
			gType int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*), MAX(type) FROM user_auctionfilter WHERE goodsID=$1`,
			goodsAfDup).Scan(&n, &gType); err != nil {
			t.Fatalf("count dup: %v", err)
		}
		if n != 1 {
			t.Fatalf("dup goodsID count: got %d, want 1", n)
		}
		if gType != 1 {
			t.Fatalf("dup goodsID type: got %d, want 1 (first-write-wins pin)", gType)
		}
	})
}
