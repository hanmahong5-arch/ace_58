// Package database — integration test for aion_DeleteAllPromotionCoolTime.
//
// Server-wide promo decommission. Single-arg DELETE keyed on promotion_id
// only (NOT char_id). Returns rows-affected so the caller can record
// "swept N rows" telemetry after a promo wraps.
//
// Test matrix:
//   - sweep an active promo (3 rows across 3 chars) → returns 3, all gone
//   - sweep a missing promo                          → returns 0 (no-op)
//   - sibling promo on same chars NOT touched (only target promo deleted)
//   - second sweep of the same promo                 → returns 0 (idempotent)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidDelAllPromoA      = 9001970 // owner of (300, 301)
	cidDelAllPromoB      = 9001971 // owner of (300, 302)
	cidDelAllPromoC      = 9001972 // owner of (300)
	delAllPromoSweep     = 300     // promo to be swept by the SP
	delAllPromoSibling   = 301     // sibling on A — must survive
	delAllPromoSiblingB  = 302     // sibling on B — must survive
	delAllPromoMissing   = 999     // promo with no rows → 0 affected
)

func deleteAllPromotionCoolTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_promotion_cooltime WHERE char_id BETWEEN 9001970 AND 9001979`); err != nil {
		t.Fatalf("deleteAllPromotionCoolTimeCleanup user_promotion_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001970 AND 9001979`); err != nil {
		t.Fatalf("deleteAllPromotionCoolTimeCleanup user_data: %v", err)
	}
}

func TestDeleteAllPromotionCoolTime(t *testing.T) {
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

	deleteAllPromotionCoolTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { deleteAllPromotionCoolTimeCleanup(t, context.Background(), pool) })

	// Seed 3 chars, each with the target promo + (some) sibling promos.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidDelAllPromoA, "dapA"},
		{cidDelAllPromoB, "dapB"},
		{cidDelAllPromoC, "dapC"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "dap_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Promotion rows. Distinct (last_promotion_time) values let us prove the
	// sibling row contents are unchanged after the sweep.
	type promoSeed struct {
		charID    int
		promoID   int16
		lastTime  int
	}
	for _, s := range []promoSeed{
		{cidDelAllPromoA, delAllPromoSweep, 1714000001},
		{cidDelAllPromoA, delAllPromoSibling, 1714000002}, // sibling — must survive
		{cidDelAllPromoB, delAllPromoSweep, 1714000003},
		{cidDelAllPromoB, delAllPromoSiblingB, 1714000004}, // sibling — must survive
		{cidDelAllPromoC, delAllPromoSweep, 1714000005},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_promotion_cooltime(
			    char_id, promotion_id, last_promotion_time, received_item_count,
			    cycle_received_item_count, cycle_next_reset_time)
			 VALUES ($1, $2, $3, 1, 0, 0)`,
			s.charID, s.promoID, s.lastTime); err != nil {
			t.Fatalf("seed promo (%d, %d): %v", s.charID, s.promoID, err)
		}
	}

	t.Run("sweep active promo deletes all rows of that promo and returns 3", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteallpromotioncooltime",
			int16(delAllPromoSweep)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 3 {
			t.Fatalf("sweep active: got %d, want 3", affected)
		}

		// Target promo gone everywhere.
		var gone int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime WHERE promotion_id = $1`,
			delAllPromoSweep).Scan(&gone); err != nil {
			t.Fatalf("count gone: %v", err)
		}
		if gone != 0 {
			t.Fatalf("sweep incomplete: got %d rows for promo %d, want 0", gone, delAllPromoSweep)
		}
	})

	t.Run("sibling promos are NOT touched", func(t *testing.T) {
		// Sibling 301 on A still present.
		var lastTime int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT last_promotion_time FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidDelAllPromoA, delAllPromoSibling).Scan(&lastTime); err != nil {
			t.Fatalf("verify sibling A: %v", err)
		}
		if lastTime != 1714000002 {
			t.Fatalf("sibling A leak: got %d, want 1714000002", lastTime)
		}
		// Sibling 302 on B still present.
		if err := pool.Inner().QueryRow(ctx,
			`SELECT last_promotion_time FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidDelAllPromoB, delAllPromoSiblingB).Scan(&lastTime); err != nil {
			t.Fatalf("verify sibling B: %v", err)
		}
		if lastTime != 1714000004 {
			t.Fatalf("sibling B leak: got %d, want 1714000004", lastTime)
		}
	})

	t.Run("sweep missing promo returns 0 (no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteallpromotioncooltime",
			int16(delAllPromoMissing)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("sweep missing: got %d, want 0", affected)
		}
	})

	t.Run("idempotent: second sweep of same promo returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteallpromotioncooltime",
			int16(delAllPromoSweep)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 0 {
			t.Fatalf("second sweep: got %d, want 0", affected)
		}
	})
}
