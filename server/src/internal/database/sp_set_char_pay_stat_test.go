// Package database — integration test for aion_SetCharPayStat.
//
// Single-column UPDATE on user_data.pay_stat. Bug-for-bug pinned:
//   - tier persists round-trip
//   - missing char_id silent no-op
//   - past delete_date: UPDATE STILL applies (intentional — billing
//     reconciliation must hit chars in soft-delete window for refunds)
//   - cross-column isolation: pay_stat write does NOT perturb the four
//     growth tiers (00239..00242 columns)
//   - boundary 0 / 255
//   - neighbour isolation
//
// char_id band: 9_590_040..9_590_049.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPayStatA       = 9590040
	cidPayStatB       = 9590041
	cidPayStatDel     = 9590042 // delete_date in the past — billing must still write
	cidPayStatMissing = 9590049
)

func setCharPayStatCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9590040 AND 9590049`); err != nil {
		t.Fatalf("setCharPayStatCleanup: %v", err)
	}
}

func TestSetCharPayStat(t *testing.T) {
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

	setCharPayStatCleanup(t, ctx, pool)
	t.Cleanup(func() { setCharPayStatCleanup(t, context.Background(), pool) })

	pastDel := int32(time.Now().Unix() - 365*24*3600)

	// Seed: A has all 4 growth columns + delete_date set to non-defaults
	// so cross-column isolation is verifiable.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id,
		    inventory_growth, cashitem_inventory_growth,
		    char_warehouse_growth, cashitem_warehouse_growth,
		    delete_date)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		cidPayStatA, "PayA", "ps_PayA",
		int16(1), int16(2), int16(3), int16(4), int32(0)); err != nil {
		t.Fatalf("seed A: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
		cidPayStatB, "PayB", "ps_PayB"); err != nil {
		t.Fatalf("seed B: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, delete_date)
		 VALUES ($1, $2, $3, $4)`,
		cidPayStatDel, "PayDel", "ps_PayDel", pastDel); err != nil {
		t.Fatalf("seed Del: %v", err)
	}

	t.Run("flag persists + 4 growth tiers untouched (cross-column isolation)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcharpaystat",
			cidPayStatA, int16(11)); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var ps, ig, cig, cwg, ccwg int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT pay_stat, inventory_growth, cashitem_inventory_growth,
			        char_warehouse_growth, cashitem_warehouse_growth
			   FROM user_data WHERE char_id = $1`,
			cidPayStatA).Scan(&ps, &ig, &cig, &cwg, &ccwg); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if ps != 11 {
			t.Fatalf("pay_stat: got %d, want 11", ps)
		}
		if ig != 1 || cig != 2 || cwg != 3 || ccwg != 4 {
			t.Fatalf("growth tiers leaked: %d/%d/%d/%d, want 1/2/3/4", ig, cig, cwg, ccwg)
		}
	})

	t.Run("missing char_id: silent no-op", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setcharpaystat",
			cidPayStatMissing, int16(7)); err != nil {
			t.Fatalf("CallSPExec missing: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE char_id = $1`,
			cidPayStatMissing).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing materialised: got %d, want 0", n)
		}
	})

	t.Run("past delete_date: UPDATE still applies (billing reconciliation pinned)", func(t *testing.T) {
		// NCSoft intentionally omits the soft-delete guard so refund
		// reconciliation reaches deleted chars too. Pinned bug-for-bug.
		if err := pool.CallSPExec(ctx, "aion_setcharpaystat",
			cidPayStatDel, int16(13)); err != nil {
			t.Fatalf("CallSPExec del: %v", err)
		}
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT pay_stat FROM user_data WHERE char_id = $1`,
			cidPayStatDel).Scan(&got); err != nil {
			t.Fatalf("verify del: %v", err)
		}
		if got != 13 {
			t.Fatalf("delete_date guard leaked: got %d, want 13 (no guard pinned for billing)", got)
		}
	})

	t.Run("boundary 0 / 255", func(t *testing.T) {
		for _, want := range []int16{0, 255} {
			if err := pool.CallSPExec(ctx, "aion_setcharpaystat",
				cidPayStatA, want); err != nil {
				t.Fatalf("CallSPExec %d: %v", want, err)
			}
			var got int16
			if err := pool.Inner().QueryRow(ctx,
				`SELECT pay_stat FROM user_data WHERE char_id = $1`,
				cidPayStatA).Scan(&got); err != nil {
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
			`SELECT pay_stat FROM user_data WHERE char_id = $1`,
			cidPayStatB).Scan(&got); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if got != 0 {
			t.Fatalf("B leaked: got %d, want 0", got)
		}
	})
}
