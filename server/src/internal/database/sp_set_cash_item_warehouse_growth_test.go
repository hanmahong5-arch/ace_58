// Package database — integration test for aion_SetCashItemWarehouseGrowth.
//
// Mirrors 00239 contract on cashitem_warehouse_growth column. Pinned:
//   - tier persists round-trip
//   - missing char_id silent no-op
//   - cross-column isolation: bumping cashitem_warehouse_growth does NOT
//     perturb char_warehouse_growth (free/paid partition)
//   - boundary 0 / 255
//   - neighbour isolation
//
// char_id band: 9_590_030..9_590_039.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidCashWhGrowA       = 9590030
	cidCashWhGrowB       = 9590031
	cidCashWhGrowMissing = 9590039
)

func setCashItemWarehouseGrowthCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9590030 AND 9590039`); err != nil {
		t.Fatalf("setCashItemWarehouseGrowthCleanup: %v", err)
	}
}

func TestSetCashItemWarehouseGrowth(t *testing.T) {
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

	setCashItemWarehouseGrowthCleanup(t, ctx, pool)
	t.Cleanup(func() { setCashItemWarehouseGrowthCleanup(t, context.Background(), pool) })

	// Seed with non-zero base warehouse tier to verify partition.
	for _, seed := range []struct {
		id        int
		name      string
		baseGrow  int16
	}{
		{cidCashWhGrowA, "CashWhA", 3},
		{cidCashWhGrowB, "CashWhB", 0},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, char_warehouse_growth)
			 VALUES ($1, $2, $3, $4)`,
			seed.id, seed.name, "cwh_"+seed.name, seed.baseGrow); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("tier persists + base char_warehouse_growth untouched (partition)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcashitemwarehousegrowth",
			cidCashWhGrowA, int16(8)); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}

		var cash, base int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cashitem_warehouse_growth, char_warehouse_growth
			   FROM user_data WHERE char_id = $1`,
			cidCashWhGrowA).Scan(&cash, &base); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cash != 8 {
			t.Fatalf("cash tier: got %d, want 8", cash)
		}
		if base != 3 {
			t.Fatalf("base tier leaked: got %d, want 3 (free vs paid MUST stay partitioned)", base)
		}
	})

	t.Run("missing char_id: silent no-op", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcashitemwarehousegrowth",
			cidCashWhGrowMissing, int16(7)); err != nil {
			t.Fatalf("CallSPExec missing: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE char_id = $1`,
			cidCashWhGrowMissing).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing materialised: got %d, want 0", n)
		}
	})

	t.Run("boundary 0 / 255", func(t *testing.T) {
		for _, want := range []int16{0, 255} {
			if err := pool.CallSPExec(ctx, "aion_setcashitemwarehousegrowth",
				cidCashWhGrowA, want); err != nil {
				t.Fatalf("CallSPExec %d: %v", want, err)
			}
			var got int16
			if err := pool.Inner().QueryRow(ctx,
				`SELECT cashitem_warehouse_growth FROM user_data WHERE char_id = $1`,
				cidCashWhGrowA).Scan(&got); err != nil {
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
			`SELECT cashitem_warehouse_growth FROM user_data WHERE char_id = $1`,
			cidCashWhGrowB).Scan(&got); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if got != 0 {
			t.Fatalf("B leaked: got %d, want 0", got)
		}
	})
}
