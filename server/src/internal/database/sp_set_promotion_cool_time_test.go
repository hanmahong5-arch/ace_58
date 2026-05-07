// Package database — integration test for aion_SetPromotionCooltime (upsert).
//
// Atomic INSERT-or-UPDATE on user_promotion_cooltime keyed by (char_id,
// promotion_id). Test matrix:
//   - first call inserts a row, returns 1
//   - second call same key updates all 4 cooldown columns in place (no dup)
//   - second promotion on same char inserts a new row (does not collide)
//   - neighbour char does not collide on the same promotion_id
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidSetPromoA = 9001984 // upsert target
	cidSetPromoB = 9001985 // separate char to confirm row isolation
)

func setPromotionCooltimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_promotion_cooltime WHERE char_id BETWEEN 9001984 AND 9001989`); err != nil {
		t.Fatalf("setPromotionCooltimeCleanup user_promotion_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001984 AND 9001989`); err != nil {
		t.Fatalf("setPromotionCooltimeCleanup user_data: %v", err)
	}
}

func TestSetPromotionCooltime(t *testing.T) {
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

	setPromotionCooltimeCleanup(t, ctx, pool)
	t.Cleanup(func() { setPromotionCooltimeCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidSetPromoA, "spA"},
		{cidSetPromoB, "spB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "spct_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("first set inserts new row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpromotioncooltime",
			cidSetPromoA, int16(300), 1714111111, 1, 0, 1714197511).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first set: got %d, want 1", affected)
		}

		var lastTime, recv, cycRecv, cycReset int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT last_promotion_time, received_item_count,
			        cycle_received_item_count, cycle_next_reset_time
			   FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidSetPromoA, 300).Scan(&lastTime, &recv, &cycRecv, &cycReset); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if lastTime != 1714111111 || recv != 1 || cycRecv != 0 || cycReset != 1714197511 {
			t.Fatalf("inserted: got (%d, %d, %d, %d), want (1714111111, 1, 0, 1714197511)",
				lastTime, recv, cycRecv, cycReset)
		}
	})

	t.Run("second set on same key updates in place (no duplicate)", func(t *testing.T) {
		var affected int
		// Update with all 4 fields advanced (claim happened: tick + cap + cycle reset).
		if err := pool.CallSPRow(ctx, "aion_setpromotioncooltime",
			cidSetPromoA, int16(300), 1714200000, 2, 1, 1714286400).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("update: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime WHERE char_id = $1 AND promotion_id = $2`,
			cidSetPromoA, 300).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after update: got %d, want 1", rowCnt)
		}

		var lastTime, recv, cycRecv, cycReset int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT last_promotion_time, received_item_count,
			        cycle_received_item_count, cycle_next_reset_time
			   FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidSetPromoA, 300).Scan(&lastTime, &recv, &cycRecv, &cycReset); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if lastTime != 1714200000 || recv != 2 || cycRecv != 1 || cycReset != 1714286400 {
			t.Fatalf("updated: got (%d, %d, %d, %d), want (1714200000, 2, 1, 1714286400)",
				lastTime, recv, cycRecv, cycReset)
		}
	})

	t.Run("different promotion on same char inserts new row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpromotioncooltime",
			cidSetPromoA, int16(301), 1714300000, 5, 5, 1714386400).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("new promo: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime WHERE char_id = $1`,
			cidSetPromoA).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 2 {
			t.Fatalf("rows for char A: got %d, want 2 (promo 300 + 301)", rowCnt)
		}
	})

	t.Run("neighbour char does not collide on same promotion_id", func(t *testing.T) {
		// promo_id = 300 on char B — same promo_id as A's first row, must
		// land as a separate row (PK is composite (char_id, promotion_id)).
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpromotioncooltime",
			cidSetPromoB, int16(300), 1715000000, 9, 9, 1715086400).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("neighbour insert: got %d, want 1", affected)
		}

		// Char A's row at promo 300 still has its v2 payload.
		var lastTime int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT last_promotion_time FROM user_promotion_cooltime
			  WHERE char_id = $1 AND promotion_id = $2`,
			cidSetPromoA, 300).Scan(&lastTime); err != nil {
			t.Fatalf("verify A untouched: %v", err)
		}
		if lastTime != 1714200000 {
			t.Fatalf("A leak: got %d, want 1714200000", lastTime)
		}
	})
}
