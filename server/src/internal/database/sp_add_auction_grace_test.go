// Package database — integration test for aion_AddAuctionGrace.
//
// INSERT into user_grace with state hard-pinned at 0; returns BIGINT
// grace_id (T-SQL @@identity → PG RETURNING). user_grace is first-introduced
// in 00227.
//
// Test matrix:
//   - first call inserts, returns positive grace_id, payload round-trips
//   - state column is hard-pinned at 0 (NCSoft contract)
//   - sequential calls return monotonically increasing grace_ids
//   - same (owner_id, goods_id, building_id) coexist (no dedup, audit-style)
//
// owner_id band: 9_560_001..9_560_039 (R18 batch — grace add subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAgA   = 9560001 // first grace insert
	cidAgB   = 9560002 // second insert, monotonicity check
	cidAgDup = 9560003 // exercises no-dedup pin
)

func addAuctionGraceCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_grace WHERE owner_id BETWEEN 9560001 AND 9560039`); err != nil {
		t.Fatalf("addAuctionGraceCleanup: %v", err)
	}
}

func TestAddAuctionGrace(t *testing.T) {
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

	addAuctionGraceCleanup(t, ctx, pool)
	t.Cleanup(func() { addAuctionGraceCleanup(t, context.Background(), pool) })

	t.Run("first call inserts, returns positive grace_id, payload round-trip", func(t *testing.T) {
		var graceID int64
		if err := pool.CallSPRow(ctx, "aion_addauctiongrace",
			int(cidAgA), int(50001), int(70001), int(1700000000)).Scan(&graceID); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if graceID <= 0 {
			t.Fatalf("grace_id: got %d, want > 0", graceID)
		}

		var (
			ownerID    int
			goodsID    int
			buildingID int
			startTime  int
			state      int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT owner_id, goods_id, building_id, starttime, state
			   FROM user_grace WHERE grace_id=$1`,
			graceID).Scan(&ownerID, &goodsID, &buildingID, &startTime, &state); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if ownerID != cidAgA || goodsID != 50001 || buildingID != 70001 || startTime != 1700000000 {
			t.Fatalf("payload: owner=%d goods=%d building=%d start=%d, want %d/50001/70001/1700000000",
				ownerID, goodsID, buildingID, startTime, cidAgA)
		}
		if state != 0 {
			t.Fatalf("state hard-pin: got %d, want 0", state)
		}
	})

	t.Run("sequential calls return monotonically increasing grace_ids", func(t *testing.T) {
		var id1 int64
		if err := pool.CallSPRow(ctx, "aion_addauctiongrace",
			int(cidAgB), int(50002), int(70002), int(1700000100)).Scan(&id1); err != nil {
			t.Fatalf("CallSPRow id1: %v", err)
		}

		var id2 int64
		if err := pool.CallSPRow(ctx, "aion_addauctiongrace",
			int(cidAgB), int(50003), int(70003), int(1700000200)).Scan(&id2); err != nil {
			t.Fatalf("CallSPRow id2: %v", err)
		}

		if id2 <= id1 {
			t.Fatalf("monotonicity: id1=%d id2=%d, want id2 > id1", id1, id2)
		}
	})

	t.Run("same (owner, goods, building) coexist (no dedup pin)", func(t *testing.T) {
		// NCSoft does not dedup on (owner_id, goods_id, building_id) — this
		// is an event log of grace periods (a building could be auctioned
		// repeatedly over time and produce multiple grace entries).
		var id1, id2 int64
		if err := pool.CallSPRow(ctx, "aion_addauctiongrace",
			int(cidAgDup), int(50099), int(70099), int(1700001000)).Scan(&id1); err != nil {
			t.Fatalf("CallSPRow dup1: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_addauctiongrace",
			int(cidAgDup), int(50099), int(70099), int(1700001100)).Scan(&id2); err != nil {
			t.Fatalf("CallSPRow dup2: %v", err)
		}
		if id1 == id2 {
			t.Fatalf("dup grace_ids must differ: id1=%d id2=%d", id1, id2)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_grace WHERE owner_id=$1`,
			cidAgDup).Scan(&n); err != nil {
			t.Fatalf("count dup: %v", err)
		}
		if n != 2 {
			t.Fatalf("dup count: got %d, want 2 (no-dedup pin)", n)
		}
	})
}
