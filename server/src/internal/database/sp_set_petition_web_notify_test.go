// Package database — integration test for aion_SetPetitionWebNotify (idempotent upsert).
//
// Atomic INSERT-or-NoOp on user_petition_web keyed by char_id (UNIQUE).
// Test matrix:
//   - first call → returns 1 (newly inserted), row exists in table
//   - second call on same char → returns 0 (already opted in), no duplicate
//   - distinct chars do not collide — each gets its own row
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPetWebSetA = 9001953 // first opt-in
	cidPetWebSetB = 9001954 // second opt-in (isolation)
)

func setPetitionWebNotifyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_petition_web WHERE char_id BETWEEN 9001953 AND 9001959`); err != nil {
		t.Fatalf("setPetitionWebNotifyCleanup user_petition_web: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001953 AND 9001959`); err != nil {
		t.Fatalf("setPetitionWebNotifyCleanup user_data: %v", err)
	}
}

func TestSetPetitionWebNotify(t *testing.T) {
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

	setPetitionWebNotifyCleanup(t, ctx, pool)
	t.Cleanup(func() { setPetitionWebNotifyCleanup(t, context.Background(), pool) })

	for _, cid := range []int{cidPetWebSetA, cidPetWebSetB} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1::INT, 'pws_'||$1::INT::TEXT, 'pwsu_'||$1::INT::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	t.Run("first opt-in inserts new row and returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionwebnotify",
			cidPetWebSetA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first opt-in: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_web WHERE char_id = $1`,
			cidPetWebSetA).Scan(&rowCnt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("after first opt-in: got %d rows, want 1", rowCnt)
		}
	})

	t.Run("second opt-in is a no-op (returns 0, no duplicate row)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionwebnotify",
			cidPetWebSetA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 0 {
			t.Fatalf("second opt-in: got %d, want 0 (already opted in)", affected)
		}

		// UNIQUE(char_id) plus DO NOTHING => still exactly 1 row.
		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_web WHERE char_id = $1`,
			cidPetWebSetA).Scan(&rowCnt); err != nil {
			t.Fatalf("verify dup: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("after re-opt-in: got %d rows, want 1 (no duplicate)", rowCnt)
		}
	})

	t.Run("distinct chars get independent rows", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionwebnotify",
			cidPetWebSetB).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow distinct: %v", err)
		}
		if affected != 1 {
			t.Fatalf("distinct char opt-in: got %d, want 1", affected)
		}

		var totalCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_web WHERE char_id BETWEEN $1 AND $2`,
			cidPetWebSetA, cidPetWebSetB).Scan(&totalCnt); err != nil {
			t.Fatalf("count both: %v", err)
		}
		if totalCnt != 2 {
			t.Fatalf("two chars: got %d rows, want 2", totalCnt)
		}
	})
}
