// Package database — integration test for aion_DeletePromotionCoolTime.
//
// Single-row DELETE keyed on (char_id, promotion_id). Per-player counterpart
// of 00184 (DeleteAllPromotionCoolTime). Returns rows-affected so the caller
// can distinguish "row deleted" (1) from "no-op on missing row" (0).
//
// Test matrix:
//   - delete an existing row             → returns 1, row gone
//   - delete a missing row               → returns 0 (no-op)
//   - sibling rows on same char untouched (only the requested promo)
//   - neighbour char's row at same promo untouched (composite-key scoping)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidDelPromoA = 9001973 // owner with multiple promos
	cidDelPromoB = 9001974 // neighbour, must not collide
)

func deletePromotionCoolTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_promotion_cooltime WHERE char_id BETWEEN 9001973 AND 9001975`); err != nil {
		t.Fatalf("deletePromotionCoolTimeCleanup user_promotion_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001973 AND 9001975`); err != nil {
		t.Fatalf("deletePromotionCoolTimeCleanup user_data: %v", err)
	}
}

func TestDeletePromotionCoolTime(t *testing.T) {
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

	deletePromotionCoolTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { deletePromotionCoolTimeCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidDelPromoA, "dpA"},
		{cidDelPromoB, "dpB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "dp_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Char A: two promotions to test sibling isolation.
	// Char B: same promo_id 400 as A to test composite-key scoping.
	for _, s := range []struct {
		charID  int
		promoID int16
	}{
		{cidDelPromoA, 400}, // target
		{cidDelPromoA, 401}, // sibling on same char — must survive
		{cidDelPromoB, 400}, // neighbour at same promo — must survive
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_promotion_cooltime(
			    char_id, promotion_id, last_promotion_time, received_item_count,
			    cycle_received_item_count, cycle_next_reset_time)
			 VALUES ($1, $2, 1714000000, 1, 0, 0)`,
			s.charID, s.promoID); err != nil {
			t.Fatalf("seed promo (%d, %d): %v", s.charID, s.promoID, err)
		}
	}

	t.Run("delete existing row returns 1 and removes only that row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletepromotioncooltime",
			cidDelPromoA, int16(400)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("delete existing: got %d, want 1", affected)
		}

		// Target gone.
		var gone int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidDelPromoA, 400).Scan(&gone); err != nil {
			t.Fatalf("count gone: %v", err)
		}
		if gone != 0 {
			t.Fatalf("target still exists: got %d rows, want 0", gone)
		}

		// Sibling on A (promo 401) still present.
		var sibling int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidDelPromoA, 401).Scan(&sibling); err != nil {
			t.Fatalf("count sibling: %v", err)
		}
		if sibling != 1 {
			t.Fatalf("sibling promo 401 affected: got %d rows, want 1", sibling)
		}

		// Neighbour char B at promo 400 still present (composite-key scoping).
		var neighbour int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidDelPromoB, 400).Scan(&neighbour); err != nil {
			t.Fatalf("count neighbour: %v", err)
		}
		if neighbour != 1 {
			t.Fatalf("neighbour char B leak: got %d rows, want 1", neighbour)
		}
	})

	t.Run("delete missing row returns 0 (no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletepromotioncooltime",
			cidDelPromoA, int16(999)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("delete missing: got %d, want 0", affected)
		}
	})
}
