// Package database — integration test for aion_RemoveRecipe.
//
// Pure DELETE on user_recipe PK(char_id, recipe_id). Returns rows-affected.
// 1 if a row was purged, 0 if (char_id, recipe_id) was never learned —
// NCSoft @@ROWCOUNT = 0 with no error. The DELETE is unconditional w.r.t.
// remain_count: even rows with remaining charges are purged on call (the
// "GM revoke" pin in 00221).
//
// Test matrix:
//   - existing recipe purged: 1 row affected, row gone
//   - non-existent (char_id, recipe_id): 0 rows affected, no error
//   - remain_count > 0 still purged (GM-revoke pin)
//   - delete one recipe leaves siblings of same char untouched
//   - re-add after delete works (PK no longer collides)
//
// char_id band: 9_550_021..9_550_029 (R17 batch — remove subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidRmRcA       = 9550021
	cidRmRcB       = 9550022
	cidRmRcCharged = 9550023 // exercises remain_count > 0 GM-revoke pin
	cidRmRcMissing = 9550024
)

func removeRecipeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_recipe WHERE char_id BETWEEN 9550021 AND 9550029`); err != nil {
		t.Fatalf("removeRecipeCleanup user_recipe: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9550021 AND 9550029`); err != nil {
		t.Fatalf("removeRecipeCleanup user_data: %v", err)
	}
}

func TestRemoveRecipe(t *testing.T) {
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

	removeRecipeCleanup(t, ctx, pool)
	t.Cleanup(func() { removeRecipeCleanup(t, context.Background(), pool) })

	// Seed user_data + recipes (per char).
	type seed struct {
		id     int
		name   string
		recipe int
		remain int16
	}
	seeds := []seed{
		{cidRmRcA, "RmRcA", 32001, 1},
		{cidRmRcB, "RmRcB", 32002, 4},
		{cidRmRcCharged, "RmRcCharged", 32003, 200},
	}
	for _, s := range seeds {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			s.id, s.name, "rm_"+s.name); err != nil {
			t.Fatalf("seed user_data %d: %v", s.id, err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_recipe(char_id, recipe_id, remain_count) VALUES ($1, $2, $3)`,
			s.id, s.recipe, s.remain); err != nil {
			t.Fatalf("seed user_recipe %d: %v", s.id, err)
		}
	}

	t.Run("existing recipe purged: 1 row affected, row gone", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_removerecipe",
			cidRmRcA, int(32001)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidRmRcA, 32001).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("after delete: got %d rows, want 0", n)
		}
	})

	t.Run("non-existent recipe: 0 rows affected, no error", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_removerecipe",
			cidRmRcMissing, int(32999)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing: got %d, want 0", affected)
		}
	})

	t.Run("remain_count > 0 still purged (GM-revoke pin)", func(t *testing.T) {
		// Pin: RemoveRecipe is unconditional. A recipe with 200 unused charges
		// is purged just the same — that IS the NCSoft GM-revoke contract.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_removerecipe",
			cidRmRcCharged, int(32003)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow charged: %v", err)
		}
		if affected != 1 {
			t.Fatalf("charged purge: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe WHERE char_id=$1`,
			cidRmRcCharged).Scan(&n); err != nil {
			t.Fatalf("count after charged purge: %v", err)
		}
		if n != 0 {
			t.Fatalf("charged purge: got %d rows, want 0", n)
		}
	})

	t.Run("delete one recipe leaves siblings untouched", func(t *testing.T) {
		// Add a sibling recipe to cidRmRcB (which still has 32002 from seed).
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_recipe(char_id, recipe_id, remain_count) VALUES ($1, $2, $3)`,
			cidRmRcB, 32099, int16(7)); err != nil {
			t.Fatalf("seed sibling: %v", err)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_removerecipe",
			cidRmRcB, int(32002)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow sibling test: %v", err)
		}
		if affected != 1 {
			t.Fatalf("sibling test affected: got %d, want 1", affected)
		}

		// 32002 should be gone, 32099 should remain.
		var nGone, nKept int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidRmRcB, 32002).Scan(&nGone); err != nil {
			t.Fatalf("count gone: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidRmRcB, 32099).Scan(&nKept); err != nil {
			t.Fatalf("count kept: %v", err)
		}
		if nGone != 0 || nKept != 1 {
			t.Fatalf("isolation: gone=%d kept=%d, want 0/1", nGone, nKept)
		}
	})

	t.Run("re-add after delete works (PK free again)", func(t *testing.T) {
		// cidRmRcA's 32001 was purged in the first sub-test.
		// PutRecipe of the same PK must now succeed.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidRmRcA, int(32001), int16(3)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow re-add: %v", err)
		}
		if affected != 1 {
			t.Fatalf("re-add affected: got %d, want 1", affected)
		}

		var remain int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidRmRcA, 32001).Scan(&remain); err != nil {
			t.Fatalf("verify re-add: %v", err)
		}
		if remain != 3 {
			t.Fatalf("re-add remain: got %d, want 3", remain)
		}
	})
}
