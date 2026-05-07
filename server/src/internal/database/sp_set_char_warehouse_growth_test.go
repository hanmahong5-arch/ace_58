// Package database — integration test for aion_SetCharWarehouseGrowth.
//
// Mirrors 00239 contract on char_warehouse_growth column. Pinned:
//   - tier persists round-trip
//   - missing char_id silent no-op
//   - cross-column isolation: bumping char_warehouse_growth does NOT
//     perturb cashitem_warehouse_growth (paired free/paid partition)
//   - boundary 0 / 255
//   - neighbour isolation
//
// char_id band: 9_590_020..9_590_029.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidCharWhGrowA       = 9590020
	cidCharWhGrowB       = 9590021
	cidCharWhGrowMissing = 9590029
)

func setCharWarehouseGrowthCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9590020 AND 9590029`); err != nil {
		t.Fatalf("setCharWarehouseGrowthCleanup: %v", err)
	}
}

func TestSetCharWarehouseGrowth(t *testing.T) {
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

	setCharWarehouseGrowthCleanup(t, ctx, pool)
	t.Cleanup(func() { setCharWarehouseGrowthCleanup(t, context.Background(), pool) })

	// Seed with non-zero cashitem_warehouse_growth to verify partition.
	for _, seed := range []struct {
		id        int
		name      string
		cashGrow  int16
	}{
		{cidCharWhGrowA, "CharWhA", 5},
		{cidCharWhGrowB, "CharWhB", 1},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, cashitem_warehouse_growth)
			 VALUES ($1, $2, $3, $4)`,
			seed.id, seed.name, "cw_"+seed.name, seed.cashGrow); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("tier persists + cashitem column untouched (partition)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcharwarehousegrowth",
			cidCharWhGrowA, int16(2)); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}

		var ch, cash int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT char_warehouse_growth, cashitem_warehouse_growth
			   FROM user_data WHERE char_id = $1`,
			cidCharWhGrowA).Scan(&ch, &cash); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if ch != 2 {
			t.Fatalf("char tier: got %d, want 2", ch)
		}
		if cash != 5 {
			t.Fatalf("cash tier leaked: got %d, want 5 (free vs paid MUST stay partitioned)", cash)
		}
	})

	t.Run("missing char_id: silent no-op", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcharwarehousegrowth",
			cidCharWhGrowMissing, int16(7)); err != nil {
			t.Fatalf("CallSPExec missing: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE char_id = $1`,
			cidCharWhGrowMissing).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing materialised: got %d, want 0", n)
		}
	})

	t.Run("boundary 0 / 255", func(t *testing.T) {
		for _, want := range []int16{0, 255} {
			if err := pool.CallSPExec(ctx, "aion_setcharwarehousegrowth",
				cidCharWhGrowA, want); err != nil {
				t.Fatalf("CallSPExec %d: %v", want, err)
			}
			var got int16
			if err := pool.Inner().QueryRow(ctx,
				`SELECT char_warehouse_growth FROM user_data WHERE char_id = $1`,
				cidCharWhGrowA).Scan(&got); err != nil {
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
			`SELECT char_warehouse_growth FROM user_data WHERE char_id = $1`,
			cidCharWhGrowB).Scan(&got); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if got != 0 {
			t.Fatalf("B leaked: got %d, want 0", got)
		}
	})
}
