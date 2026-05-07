// Package database — integration test for aion_DelMacro.
//
// Single-row DELETE keyed on (char_id, slot_id). Returns rows-affected so the
// caller can distinguish "slot deleted" (1) from "no-op on missing slot" (0).
//
// Test matrix:
//   - delete an existing slot → returns 1, row gone, sibling slots preserved
//   - delete a missing slot   → returns 0 (no-op), no error
//   - delete only targets the requested slot, not all slots of the char
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidMacroDelA = 9001944 // owner with multiple slots
)

func delMacroCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_macro WHERE char_id BETWEEN 9001944 AND 9001949`); err != nil {
		t.Fatalf("delMacroCleanup user_macro: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001944 AND 9001949`); err != nil {
		t.Fatalf("delMacroCleanup user_data: %v", err)
	}
}

func TestDelMacro(t *testing.T) {
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

	delMacroCleanup(t, ctx, pool)
	t.Cleanup(func() { delMacroCleanup(t, context.Background(), pool) })

	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
		cidMacroDelA, "MacDelA", "md_MacDelA"); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	// Seed two slots so we can verify that Del targets exactly one of them.
	for _, slot := range []int16{1, 2} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_macro(char_id, slot_id, data) VALUES ($1, $2, $3)`,
			cidMacroDelA, slot, []byte{0x99, byte(slot)}); err != nil {
			t.Fatalf("seed slot %d: %v", slot, err)
		}
	}

	t.Run("delete existing slot returns 1 and removes only that row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_delmacro",
			cidMacroDelA, int16(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("delete existing: got %d, want 1", affected)
		}

		// Slot 1 gone.
		var gone int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_macro WHERE char_id = $1 AND slot_id = $2`,
			cidMacroDelA, 1).Scan(&gone); err != nil {
			t.Fatalf("count gone: %v", err)
		}
		if gone != 0 {
			t.Fatalf("slot 1 still exists: got %d rows, want 0", gone)
		}

		// Slot 2 untouched.
		var sibling int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_macro WHERE char_id = $1 AND slot_id = $2`,
			cidMacroDelA, 2).Scan(&sibling); err != nil {
			t.Fatalf("count sibling: %v", err)
		}
		if sibling != 1 {
			t.Fatalf("sibling slot 2 affected: got %d rows, want 1", sibling)
		}
	})

	t.Run("delete missing slot returns 0 (no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_delmacro",
			cidMacroDelA, int16(99)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("delete missing: got %d, want 0", affected)
		}
	})
}
