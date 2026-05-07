// Package database — integration test for aion_SetCashItemInventoryGrowth.
//
// Mirrors 00239 contract on cashitem_inventory_growth column. Pinned:
//   - tier persists round-trip
//   - missing char_id is silent no-op
//   - cross-column isolation: bumping cashitem_inventory_growth does NOT
//     touch the sibling base inventory_growth (paired SPs separately
//     track free vs paid tiers — refund flow critical)
//   - boundary 0 / 255
//   - neighbour isolation
//
// char_id band: 9_590_010..9_590_019.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidCashInvGrowA       = 9590010
	cidCashInvGrowB       = 9590011
	cidCashInvGrowMissing = 9590019
)

func setCashItemInventoryGrowthCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9590010 AND 9590019`); err != nil {
		t.Fatalf("setCashItemInventoryGrowthCleanup: %v", err)
	}
}

func TestSetCashItemInventoryGrowth(t *testing.T) {
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

	setCashItemInventoryGrowthCleanup(t, ctx, pool)
	t.Cleanup(func() { setCashItemInventoryGrowthCleanup(t, context.Background(), pool) })

	// Seed with NON-zero base inventory_growth to verify cross-column
	// isolation: cashitem write must NOT clobber the base tier.
	for _, seed := range []struct {
		id          int
		name        string
		baseGrowth  int16
	}{
		{cidCashInvGrowA, "CashInvA", 4},
		{cidCashInvGrowB, "CashInvB", 2},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, inventory_growth)
			 VALUES ($1, $2, $3, $4)`,
			seed.id, seed.name, "ci_"+seed.name, seed.baseGrowth); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("tier persists + base inventory_growth untouched (cross-column isolation)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcashiteminventorygrowth",
			cidCashInvGrowA, int16(6)); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}

		var cash, base int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cashitem_inventory_growth, inventory_growth
			   FROM user_data WHERE char_id = $1`,
			cidCashInvGrowA).Scan(&cash, &base); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cash != 6 {
			t.Fatalf("cash tier: got %d, want 6", cash)
		}
		if base != 4 {
			t.Fatalf("base tier leaked: got %d, want 4 (paid vs free MUST stay partitioned)", base)
		}
	})

	t.Run("missing char_id: silent no-op", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcashiteminventorygrowth",
			cidCashInvGrowMissing, int16(3)); err != nil {
			t.Fatalf("CallSPExec missing: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE char_id = $1`,
			cidCashInvGrowMissing).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing materialised: got %d, want 0", n)
		}
	})

	t.Run("boundary 0 / 255", func(t *testing.T) {
		for _, want := range []int16{0, 255} {
			if err := pool.CallSPExec(ctx, "aion_setcashiteminventorygrowth",
				cidCashInvGrowA, want); err != nil {
				t.Fatalf("CallSPExec %d: %v", want, err)
			}
			var got int16
			if err := pool.Inner().QueryRow(ctx,
				`SELECT cashitem_inventory_growth FROM user_data WHERE char_id = $1`,
				cidCashInvGrowA).Scan(&got); err != nil {
				t.Fatalf("verify %d: %v", want, err)
			}
			if got != want {
				t.Fatalf("boundary %d: got %d", want, got)
			}
		}
	})

	t.Run("neighbour isolation", func(t *testing.T) {
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cashitem_inventory_growth FROM user_data WHERE char_id = $1`,
			cidCashInvGrowB).Scan(&got); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if got != 0 {
			t.Fatalf("B leaked: got %d, want 0", got)
		}
	})
}
