// Package database — integration test for aion_SetRecipeRemainCount.
//
// Pure UPDATE on user_recipe PK(char_id, recipe_id). Returns rows-affected.
// 1 on update, 0 if (char_id, recipe_id) not learned (NCSoft @@ROWCOUNT
// semantics). Setting remain_count=0 must NOT auto-delete — that path
// belongs to 00221 RemoveRecipe.
//
// Test matrix:
//   - update existing row: 1 row affected, new value round-trips
//   - update non-existent row: 0 rows affected, no error
//   - setting remain_count to 0 keeps the row (no auto-delete pin)
//   - tinyint-edge 255 round-trips via SMALLINT
//   - distinct rows for one char update independently
//
// char_id band: 9_550_011..9_550_019 (R17 batch — set-remain subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidSetRcA       = 9550011
	cidSetRcB       = 9550012
	cidSetRcEdge    = 9550013
	cidSetRcMissing = 9550014 // exercises 0-rows-affected pin (no row pre-existing)
)

func setRecipeRemainCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_recipe WHERE char_id BETWEEN 9550011 AND 9550019`); err != nil {
		t.Fatalf("setRecipeRemainCleanup user_recipe: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9550011 AND 9550019`); err != nil {
		t.Fatalf("setRecipeRemainCleanup user_data: %v", err)
	}
}

func TestSetRecipeRemainCount(t *testing.T) {
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

	setRecipeRemainCleanup(t, ctx, pool)
	t.Cleanup(func() { setRecipeRemainCleanup(t, context.Background(), pool) })

	// Seed user_data + a starter recipe row per char.
	for _, seed := range []struct {
		id     int
		name   string
		recipe int
		start  int16
	}{
		{cidSetRcA, "SetRcA", 31001, 5},
		{cidSetRcB, "SetRcB", 31002, 9},
		{cidSetRcEdge, "SetRcEdge", 31003, 1},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "src_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_recipe(char_id, recipe_id, remain_count) VALUES ($1, $2, $3)`,
			seed.id, seed.recipe, seed.start); err != nil {
			t.Fatalf("seed user_recipe %d/%d: %v", seed.id, seed.recipe, err)
		}
	}

	t.Run("update existing row decrements correctly", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreciperemaincount",
			cidSetRcA, int(31001), int16(4)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var remain int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidSetRcA, 31001).Scan(&remain); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if remain != 4 {
			t.Fatalf("remain after update: got %d, want 4", remain)
		}
	})

	t.Run("update non-existent (char_id, recipe_id) returns 0 rows", func(t *testing.T) {
		// cidSetRcMissing has no recipe row at all.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreciperemaincount",
			cidSetRcMissing, int(31999), int16(7)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			// NCSoft @@ROWCOUNT semantics: 0 = caller knows recipe not learned.
			t.Fatalf("missing recipe: got %d, want 0", affected)
		}
	})

	t.Run("setting remain_count to 0 does NOT auto-delete row", func(t *testing.T) {
		// Pin: SetRecipeRemainCount(0) is NOT a delete shortcut. The row
		// stays; client decides display based on remain_count=0 sentinel.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreciperemaincount",
			cidSetRcB, int(31002), int16(0)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow zero: %v", err)
		}
		if affected != 1 {
			t.Fatalf("zero update affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidSetRcB, 31002).Scan(&n); err != nil {
			t.Fatalf("count after zero: %v", err)
		}
		if n != 1 {
			t.Fatalf("auto-delete pin: row count=%d after remain=0, want 1", n)
		}

		var remain int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidSetRcB, 31002).Scan(&remain); err != nil {
			t.Fatalf("verify zero: %v", err)
		}
		if remain != 0 {
			t.Fatalf("zero round-trip: got %d, want 0", remain)
		}
	})

	t.Run("tinyint-edge 255 round-trips via SMALLINT", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreciperemaincount",
			cidSetRcEdge, int(31003), int16(255)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow 255: %v", err)
		}
		if affected != 1 {
			t.Fatalf("edge 255 affected: got %d, want 1", affected)
		}

		var remain int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidSetRcEdge, 31003).Scan(&remain); err != nil {
			t.Fatalf("verify edge 255: %v", err)
		}
		if remain != 255 {
			t.Fatalf("edge 255 round-trip: got %d, want 255", remain)
		}
	})

	t.Run("distinct rows for one char update independently", func(t *testing.T) {
		// Add a second recipe to cidSetRcA; updating one MUST not touch the other.
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_recipe(char_id, recipe_id, remain_count) VALUES ($1, $2, $3)`,
			cidSetRcA, 31010, int16(8)); err != nil {
			t.Fatalf("seed second recipe: %v", err)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_setreciperemaincount",
			cidSetRcA, int(31010), int16(2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second update affected: got %d, want 1", affected)
		}

		// Re-verify the FIRST recipe (31001 → 4 from earlier test) untouched.
		var first, second int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidSetRcA, 31001).Scan(&first); err != nil {
			t.Fatalf("verify first untouched: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidSetRcA, 31010).Scan(&second); err != nil {
			t.Fatalf("verify second updated: %v", err)
		}
		if first != 4 {
			t.Fatalf("isolation: first recipe got %d, want 4 (unchanged)", first)
		}
		if second != 2 {
			t.Fatalf("isolation: second recipe got %d, want 2 (updated)", second)
		}
	})
}
