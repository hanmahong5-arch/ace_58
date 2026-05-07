// Package database — integration test for aion_SetAuctionGrace.
//
// Pure UPDATE on user_grace.state scoped by PK (grace_id). Returns
// rows-affected (NCSoft @@ROWCOUNT pin): 1 success, 0 if grace_id missing.
// No state-transition guard; negative state values accepted (NCSoft pin).
//
// Test matrix:
//   - update existing grace_id flips state, returns 1
//   - missing grace_id returns 0, no error
//   - re-update to same value returns 1 (no idempotence collapse)
//   - negative state value accepted (GM/dev flag pin)
//   - sibling grace rows are NOT touched
//
// owner_id band: 9_560_041..9_560_099 (R18 batch — grace set subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidSgA       = 9560041 // basic flip 0 → 1
	cidSgNeg     = 9560042 // exercises negative-state pin
	cidSgRepeat  = 9560043 // re-update to same value
	cidSgSibling = 9560044 // sibling row, must NOT be mutated
)

func setAuctionGraceCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_grace WHERE owner_id BETWEEN 9560041 AND 9560099`); err != nil {
		t.Fatalf("setAuctionGraceCleanup: %v", err)
	}
}

func TestSetAuctionGrace(t *testing.T) {
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

	setAuctionGraceCleanup(t, ctx, pool)
	t.Cleanup(func() { setAuctionGraceCleanup(t, context.Background(), pool) })

	// Seed grace rows via the AddAuctionGrace SP (avoids hand-rolling INSERT
	// to get authoritative grace_ids; also exercises the cross-SP contract).
	type seeded struct {
		ownerID int
		graceID int64
	}
	var (
		gA, gNeg, gRepeat, gSibling seeded
	)
	for _, s := range []struct {
		owner    int
		goods    int
		building int
		stime    int
		out      *seeded
	}{
		{cidSgA, 60001, 80001, 1700100000, &gA},
		{cidSgNeg, 60002, 80002, 1700100100, &gNeg},
		{cidSgRepeat, 60003, 80003, 1700100200, &gRepeat},
		{cidSgSibling, 60004, 80004, 1700100300, &gSibling},
	} {
		s.out.ownerID = s.owner
		if err := pool.CallSPRow(ctx, "aion_addauctiongrace",
			int(s.owner), int(s.goods), int(s.building), int(s.stime)).
			Scan(&s.out.graceID); err != nil {
			t.Fatalf("seed AddAuctionGrace owner=%d: %v", s.owner, err)
		}
	}

	t.Run("update existing grace_id flips state, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setauctiongrace",
			gA.graceID, int(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var state int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM user_grace WHERE grace_id=$1`,
			gA.graceID).Scan(&state); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if state != 1 {
			t.Fatalf("state: got %d, want 1", state)
		}
	})

	t.Run("missing grace_id returns 0, no error", func(t *testing.T) {
		// Use a grace_id far above the seeded ones — guaranteed absent.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setauctiongrace",
			int64(9_999_999_999), int(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing affected: got %d, want 0", affected)
		}
	})

	t.Run("re-update to same value still returns 1", func(t *testing.T) {
		// 0 → 2
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setauctiongrace",
			gRepeat.graceID, int(2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow first: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first affected: got %d, want 1", affected)
		}

		// 2 → 2 (no-op payload). NCSoft @@ROWCOUNT counts row matched, not
		// row changed → returns 1.
		if err := pool.CallSPRow(ctx, "aion_setauctiongrace",
			gRepeat.graceID, int(2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second affected: got %d, want 1 (NCSoft @@ROWCOUNT semantics)", affected)
		}
	})

	t.Run("negative state value accepted (GM/dev flag pin)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setauctiongrace",
			gNeg.graceID, int(-7)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow neg: %v", err)
		}
		if affected != 1 {
			t.Fatalf("neg affected: got %d, want 1", affected)
		}

		var state int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM user_grace WHERE grace_id=$1`,
			gNeg.graceID).Scan(&state); err != nil {
			t.Fatalf("verify neg: %v", err)
		}
		if state != -7 {
			t.Fatalf("neg round-trip: got %d, want -7", state)
		}
	})

	t.Run("sibling grace rows untouched by Set", func(t *testing.T) {
		// gSibling was seeded but never targeted; state must still be 0.
		var state int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM user_grace WHERE grace_id=$1`,
			gSibling.graceID).Scan(&state); err != nil {
			t.Fatalf("verify sibling: %v", err)
		}
		if state != 0 {
			t.Fatalf("sibling state: got %d, want 0 (must be untouched)", state)
		}
	})
}
