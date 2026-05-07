// Package database — integration test for aion_SetInventoryGrowth.
//
// Single-column UPDATE bug-for-bug pinned:
//   - happy path: tier persists round-trip
//   - missing char_id: silent no-op (no error, no row materialised)
//   - delete_date past (char "dead"): UPDATE STILL applies — NCSoft
//     intentionally omits the soft-delete guard here (contrast with
//     00208 ChangeEnhancedStigmaSlotCnt which DOES guard). Pinned.
//   - boundary: 0 (reset) and 255 (TINYINT max in T-SQL)
//   - neighbour isolation: A's update doesn't perturb B
//
// char_id band: 9_590_001..9_590_099 (batch-21 reserve).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidInvGrowA       = 9590001 // happy-path target
	cidInvGrowB       = 9590002 // neighbour isolation
	cidInvGrowDelPast = 9590003 // delete_date in the past — confirm guard absent
	cidInvGrowMissing = 9590099 // never seeded — no-op verification
)

func setInventoryGrowthCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9590001 AND 9590099`); err != nil {
		t.Fatalf("setInventoryGrowthCleanup: %v", err)
	}
}

func TestSetInventoryGrowth(t *testing.T) {
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

	setInventoryGrowthCleanup(t, ctx, pool)
	t.Cleanup(func() { setInventoryGrowthCleanup(t, context.Background(), pool) })

	// Past delete_date — char treated as soft-deleted in T-SQL guards
	// elsewhere. The current SP has NO guard; we assert that bug-for-bug.
	pastDel := int32(time.Now().Unix() - 365*24*3600)

	for _, seed := range []struct {
		id   int
		name string
		del  int32
	}{
		{cidInvGrowA, "InvGrowA", 0},
		{cidInvGrowB, "InvGrowB", 0},
		{cidInvGrowDelPast, "InvGrowDel", pastDel},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, delete_date)
			 VALUES ($1, $2, $3, $4)`,
			seed.id, seed.name, "ig_"+seed.name, seed.del); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("happy path: tier persists round-trip", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setinventorygrowth",
			cidInvGrowA, int16(3)); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT inventory_growth FROM user_data WHERE char_id = $1`,
			cidInvGrowA).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 3 {
			t.Fatalf("tier: got %d, want 3", got)
		}
	})

	t.Run("missing char_id: silent no-op (no row materialised)", func(t *testing.T) {
		// SP must succeed silently; no row should appear afterwards.
		if err := pool.CallSPExec(ctx, "aion_setinventorygrowth",
			cidInvGrowMissing, int16(7)); err != nil {
			t.Fatalf("CallSPExec missing: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE char_id = $1`,
			cidInvGrowMissing).Scan(&n); err != nil {
			t.Fatalf("count missing: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing should not materialise: got %d, want 0", n)
		}
	})

	t.Run("past delete_date: UPDATE still applies (no guard, pinned)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setinventorygrowth",
			cidInvGrowDelPast, int16(5)); err != nil {
			t.Fatalf("CallSPExec del: %v", err)
		}
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT inventory_growth FROM user_data WHERE char_id = $1`,
			cidInvGrowDelPast).Scan(&got); err != nil {
			t.Fatalf("verify del: %v", err)
		}
		if got != 5 {
			t.Fatalf("delete_date guard leaked: got %d, want 5 (no guard pinned)", got)
		}
	})

	t.Run("boundary: 0 (reset) and 255 (TINYINT max)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setinventorygrowth",
			cidInvGrowA, int16(0)); err != nil {
			t.Fatalf("CallSPExec 0: %v", err)
		}
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT inventory_growth FROM user_data WHERE char_id = $1`,
			cidInvGrowA).Scan(&got); err != nil {
			t.Fatalf("verify 0: %v", err)
		}
		if got != 0 {
			t.Fatalf("tier=0: got %d, want 0", got)
		}

		if err := pool.CallSPExec(ctx, "aion_setinventorygrowth",
			cidInvGrowA, int16(255)); err != nil {
			t.Fatalf("CallSPExec 255: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT inventory_growth FROM user_data WHERE char_id = $1`,
			cidInvGrowA).Scan(&got); err != nil {
			t.Fatalf("verify 255: %v", err)
		}
		if got != 255 {
			t.Fatalf("tier=255: got %d, want 255", got)
		}
	})

	t.Run("neighbour isolation", func(t *testing.T) {
		// B should still hold its default 0.
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT inventory_growth FROM user_data WHERE char_id = $1`,
			cidInvGrowB).Scan(&got); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if got != 0 {
			t.Fatalf("B leaked: got %d, want 0", got)
		}

		// Bump B; A must keep 255 from boundary case.
		if err := pool.CallSPExec(ctx, "aion_setinventorygrowth",
			cidInvGrowB, int16(9)); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}
		var aGot int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT inventory_growth FROM user_data WHERE char_id = $1`,
			cidInvGrowA).Scan(&aGot); err != nil {
			t.Fatalf("verify A intact: %v", err)
		}
		if aGot != 255 {
			t.Fatalf("A leaked from B: got %d, want 255", aGot)
		}
	})
}
