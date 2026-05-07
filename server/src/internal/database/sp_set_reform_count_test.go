// Package database — integration test for aion_SetReformCount.
//
// UPSERT (char_id PK) on user_reform with (next_reset_time, reform_count).
// NCSoft pattern is UPDATE-then-INSERT-if-no-row; we collapse to ON CONFLICT.
// Both branches return 1 (rows-affected); caller cannot distinguish
// insert vs update from the return value (matches NCSoft @@ROWCOUNT).
//
// Test matrix:
//   - first call inserts 1 row, both columns round-trip
//   - second call same char updates both columns; row count stays 1
//   - distinct char_ids coexist (no collision)
//   - negative reform_count + negative next_reset_time accepted
//     (bug-for-bug pin — useful for GM corrections)
//   - missing user_data: SetReformCount still succeeds (no FK)
//
// char_id band: 9_540_030..9_540_039 (R16 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidReformSetA       = 9540030
	cidReformSetB       = 9540031
	cidReformSetNeg     = 9540032 // exercises negative-value pin
	cidReformSetOrphan  = 9540039 // intentionally NOT seeded into user_data
)

func setReformCountCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_reform WHERE char_id BETWEEN 9540030 AND 9540039`); err != nil {
		t.Fatalf("setReformCountCleanup user_reform: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9540030 AND 9540039`); err != nil {
		t.Fatalf("setReformCountCleanup user_data: %v", err)
	}
}

func TestSetReformCount(t *testing.T) {
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

	setReformCountCleanup(t, ctx, pool)
	t.Cleanup(func() { setReformCountCleanup(t, context.Background(), pool) })

	// Seed user_data for chars where parent existence matters semantically.
	// cidReformSetOrphan stays unseeded — exercises no-FK orphan-tolerance.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidReformSetA, "RfSetA"},
		{cidReformSetB, "RfSetB"},
		{cidReformSetNeg, "RfSetNeg"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "rfs_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first call inserts, full round-trip", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreformcount",
			cidReformSetA, int(1700001000), int(7)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow first: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first: got affected=%d, want 1", affected)
		}

		var (
			nextReset, count int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT next_reset_time, reform_count FROM user_reform WHERE char_id=$1`,
			cidReformSetA).Scan(&nextReset, &count); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if nextReset != 1700001000 || count != 7 {
			t.Fatalf("first payload: reset=%d count=%d, want 1700001000/7",
				nextReset, count)
		}
	})

	t.Run("second call same char updates both columns, row count still 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreformcount",
			cidReformSetA, int(1700099000), int(42)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow update: %v", err)
		}
		if affected != 1 {
			// NCSoft @@ROWCOUNT semantics: update branch returns 1.
			t.Fatalf("update: got affected=%d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_reform WHERE char_id=$1`,
			cidReformSetA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("after update: got %d rows, want 1", cnt)
		}

		var (
			nextReset, count int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT next_reset_time, reform_count FROM user_reform WHERE char_id=$1`,
			cidReformSetA).Scan(&nextReset, &count); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if nextReset != 1700099000 || count != 42 {
			t.Fatalf("updated payload: reset=%d count=%d, want 1700099000/42",
				nextReset, count)
		}
	})

	t.Run("distinct char_ids coexist", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreformcount",
			cidReformSetB, int(1700002000), int(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B insert affected: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_reform WHERE char_id IN ($1, $2)`,
			cidReformSetA, cidReformSetB).Scan(&cnt); err != nil {
			t.Fatalf("count two chars: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("two chars: got %d rows, want 2", cnt)
		}
	})

	t.Run("negative values accepted (bug-for-bug pin)", func(t *testing.T) {
		// Pin: NCSoft has no CHECK constraints; GM tools occasionally write
		// negative reform_count to grant "unlimited reforms this cycle"
		// semantics. We must accept them without erroring.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreformcount",
			cidReformSetNeg, int(-1), int(-9999)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow negative: %v", err)
		}
		if affected != 1 {
			t.Fatalf("negative: got affected=%d, want 1", affected)
		}

		var (
			nextReset, count int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT next_reset_time, reform_count FROM user_reform WHERE char_id=$1`,
			cidReformSetNeg).Scan(&nextReset, &count); err != nil {
			t.Fatalf("verify negative: %v", err)
		}
		if nextReset != -1 || count != -9999 {
			t.Fatalf("negative payload: reset=%d count=%d, want -1/-9999",
				nextReset, count)
		}
	})

	t.Run("missing user_data: SetReformCount still succeeds (no FK)", func(t *testing.T) {
		// Bug-for-bug pin: NCSoft has no FK on user_reform.char_id.
		// We can pin a reform-count on a char that does not exist.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreformcount",
			cidReformSetOrphan, int(1700003000), int(0)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow orphan: %v", err)
		}
		if affected != 1 {
			t.Fatalf("orphan: got affected=%d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_reform WHERE char_id=$1`,
			cidReformSetOrphan).Scan(&cnt); err != nil {
			t.Fatalf("count orphan: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("orphan: got %d rows, want 1", cnt)
		}
	})
}
