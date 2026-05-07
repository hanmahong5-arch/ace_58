// Package database — integration test for aion_ClearPetitionWebNotify.
//
// Single-row DELETE keyed on char_id. Returns rows-affected so the caller
// can distinguish "opt-out applied" (1) from "was already opted out" (0).
//
// Test matrix:
//   - clear an existing opt-in   → returns 1, row gone, sibling chars preserved
//   - clear a non-existent       → returns 0 (no-op), no error
//   - clear only targets the requested char (does NOT wipe neighbours)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPetWebClearA = 9001955 // opted-in, target of clear
	cidPetWebClearB = 9001956 // opted-in neighbour, must survive
)

func clearPetitionWebNotifyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_petition_web WHERE char_id BETWEEN 9001955 AND 9001959`); err != nil {
		t.Fatalf("clearPetitionWebNotifyCleanup user_petition_web: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001955 AND 9001959`); err != nil {
		t.Fatalf("clearPetitionWebNotifyCleanup user_data: %v", err)
	}
}

func TestClearPetitionWebNotify(t *testing.T) {
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

	clearPetitionWebNotifyCleanup(t, ctx, pool)
	t.Cleanup(func() { clearPetitionWebNotifyCleanup(t, context.Background(), pool) })

	for _, cid := range []int{cidPetWebClearA, cidPetWebClearB} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'pwc_'||$1::TEXT, 'pwcu_'||$1::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_petition_web(char_id) VALUES ($1)`, cid); err != nil {
			t.Fatalf("seed petition_web %d: %v", cid, err)
		}
	}

	t.Run("clear existing opt-in returns 1 and removes only that row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionwebnotify",
			cidPetWebClearA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("clear existing: got %d, want 1", affected)
		}

		// Target row gone.
		var gone int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_web WHERE char_id = $1`,
			cidPetWebClearA).Scan(&gone); err != nil {
			t.Fatalf("count gone: %v", err)
		}
		if gone != 0 {
			t.Fatalf("target opt-in still present: got %d rows, want 0", gone)
		}

		// Neighbour untouched.
		var sibling int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_web WHERE char_id = $1`,
			cidPetWebClearB).Scan(&sibling); err != nil {
			t.Fatalf("count sibling: %v", err)
		}
		if sibling != 1 {
			t.Fatalf("sibling opt-in affected: got %d rows, want 1", sibling)
		}
	})

	t.Run("clear non-existent opt-in returns 0 (no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionwebnotify",
			cidPetWebClearA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow no-op: %v", err)
		}
		if affected != 0 {
			t.Fatalf("clear missing: got %d, want 0", affected)
		}
	})
}
