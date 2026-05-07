// Package database — integration test for aion_DeleteBookmarkAll.
//
// Pure per-char wipe. Returns rows-affected. Empty-result is silently OK
// (returns 0). No FK guard.
//
// Test matrix:
//   - happy path: char with 3 bookmarks → wipes all 3, returns 3
//   - empty result: char with no bookmarks → returns 0, no error
//   - missing user_data: still returns 0, no error (no FK)
//   - neighbour isolation: deleting char A's bookmarks doesn't touch char B
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidDelBmA       = 9470001
	cidDelBmB       = 9470002
	cidDelBmEmpty   = 9470003 // seeded user_data, zero bookmarks
	cidDelBmMissing = 9470099 // no seed at all
)

func deleteBookmarkAllCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM bookmark WHERE char_id BETWEEN 9470001 AND 9470099`); err != nil {
		t.Fatalf("deleteBookmarkAllCleanup bookmark: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9470001 AND 9470099`); err != nil {
		t.Fatalf("deleteBookmarkAllCleanup user_data: %v", err)
	}
}

func TestDeleteBookmarkAll(t *testing.T) {
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

	deleteBookmarkAllCleanup(t, ctx, pool)
	t.Cleanup(func() { deleteBookmarkAllCleanup(t, context.Background(), pool) })

	// Seed three chars; the 4th (cidDelBmMissing) is intentionally absent.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidDelBmA, "DelBmA"},
		{cidDelBmB, "DelBmB"},
		{cidDelBmEmpty, "DelBmEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "del_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Pre-load A with 3 bookmarks via direct INSERT (bypass aion_putbookmark
	// to keep this test independent of 00200's correctness).
	for _, slot := range []int16{0, 1, 2} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO bookmark (char_id, bookmark, bookmark_name, world, x, y, z)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelBmA, slot, "A", int32(210010000), float32(0), float32(0), float32(0)); err != nil {
			t.Fatalf("seed A bookmark slot=%d: %v", slot, err)
		}
	}
	// Load B with 1 bookmark — must survive A's wipe (neighbour isolation).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO bookmark (char_id, bookmark, bookmark_name, world, x, y, z)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		cidDelBmB, int16(0), "B", int32(0), float32(0), float32(0), float32(0)); err != nil {
		t.Fatalf("seed B bookmark: %v", err)
	}

	t.Run("happy path: 3 bookmarks → wipes all 3, returns 3", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletebookmarkall", cidDelBmA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 3 {
			t.Fatalf("happy: got %d, want 3", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM bookmark WHERE char_id = $1`,
			cidDelBmA).Scan(&cnt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("rows after wipe: got %d, want 0", cnt)
		}
	})

	t.Run("neighbour isolation: B's bookmark survives A's wipe", func(t *testing.T) {
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM bookmark WHERE char_id = $1`,
			cidDelBmB).Scan(&cnt); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("B leaked: got %d, want 1", cnt)
		}
	})

	t.Run("empty result: char with no bookmarks → 0, no error", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletebookmarkall", cidDelBmEmpty).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow empty: %v", err)
		}
		if affected != 0 {
			t.Fatalf("empty: got %d, want 0", affected)
		}
	})

	t.Run("missing user_data: still returns 0 (no FK guard)", func(t *testing.T) {
		// Bug-for-bug NCSoft: no parent existence check.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletebookmarkall", cidDelBmMissing).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing: got %d, want 0", affected)
		}
	})
}
