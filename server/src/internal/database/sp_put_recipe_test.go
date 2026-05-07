// Package database — integration test for aion_PutRecipe (recipe-acquisition INSERT).
//
// Pure INSERT into user_recipe(char_id, recipe_id, remain_count). Returns
// rows-affected = 1 on success. Duplicate PK raises unique_violation by
// design — that IS the NCSoft contract (T-SQL 2627). No FK on char_id, so
// orphan rows are accepted (forensic property pinned in 00219).
//
// Test matrix:
//   - first call inserts a single row, full payload round-trips
//   - distinct (char_id, recipe_id) coexist (no collision)
//   - duplicate PK raises unique_violation (NCSoft 2627 mirror)
//   - tinyint-edge values 0 / 255 round-trip correctly through SMALLINT
//   - missing user_data: PutRecipe still succeeds (no FK pin)
//
// char_id band: 9_550_001..9_550_009 (R17 batch — recipe-write subset).
package database

import (
	"context"
	"strings"
	"testing"
	"time"
)

const (
	cidPutRcpA      = 9550001
	cidPutRcpB      = 9550002
	cidPutRcpEdge   = 9550003 // exercises 0 / 255 boundary on remain_count
	cidPutRcpDup    = 9550004 // exercises duplicate-PK pin
	cidPutRcpOrphan = 9550009 // intentionally NOT seeded into user_data
)

func putRecipeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_recipe WHERE char_id BETWEEN 9550001 AND 9550009`); err != nil {
		t.Fatalf("putRecipeCleanup user_recipe: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9550001 AND 9550009`); err != nil {
		t.Fatalf("putRecipeCleanup user_data: %v", err)
	}
}

func TestPutRecipe(t *testing.T) {
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

	putRecipeCleanup(t, ctx, pool)
	t.Cleanup(func() { putRecipeCleanup(t, context.Background(), pool) })

	// Seed user_data for chars where parent existence would matter
	// semantically. cidPutRcpOrphan stays unseeded — exercises no-FK pin.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidPutRcpA, "PutRcpA"},
		{cidPutRcpB, "PutRcpB"},
		{cidPutRcpEdge, "PutRcpEdge"},
		{cidPutRcpDup, "PutRcpDup"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "pr_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first call inserts, full payload round-trip", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpA, int(30101), int16(7)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var (
			recipeID int32
			remain   int16
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT recipe_id, remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidPutRcpA, 30101).Scan(&recipeID, &remain); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if recipeID != 30101 || remain != 7 {
			t.Fatalf("payload: recipe=%d remain=%d, want 30101/7", recipeID, remain)
		}
	})

	t.Run("distinct (char_id, recipe_id) coexist", func(t *testing.T) {
		// Same char, two different recipe ids.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpA, int(30102), int16(-1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second affected: got %d, want 1", affected)
		}

		// Different char, same recipe id as cidPutRcpA's first row — must coexist.
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpB, int(30101), int16(3)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe WHERE char_id IN ($1, $2)`,
			cidPutRcpA, cidPutRcpB).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 3 {
			t.Fatalf("after B insert: got %d rows, want 3", n)
		}
	})

	t.Run("duplicate PK raises unique_violation (NCSoft 2627 pin)", func(t *testing.T) {
		// First insert lands clean.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpDup, int(30201), int16(2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow first dup: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first dup affected: got %d, want 1", affected)
		}

		// Second insert with the same PK MUST raise unique_violation.
		// We assert the SQLSTATE class via error-string contains check —
		// pgx surfaces "23505" / "duplicate key" for unique_violation.
		err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpDup, int(30201), int16(9)).Scan(&affected)
		if err == nil {
			t.Fatal("expected unique_violation on duplicate PK, got nil")
		}
		es := err.Error()
		if !strings.Contains(es, "23505") && !strings.Contains(es, "duplicate") {
			t.Fatalf("expected 23505/duplicate-key error, got: %v", err)
		}
	})

	t.Run("tinyint-edge values (0 and 255) round-trip via SMALLINT", func(t *testing.T) {
		// 0 = consumed/expired (must NOT be auto-deleted by PutRecipe).
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpEdge, int(30301), int16(0)).Scan(&affected); err != nil {
			t.Fatalf("edge zero: %v", err)
		}
		if affected != 1 {
			t.Fatalf("edge zero affected: got %d, want 1", affected)
		}

		// 255 = max NCSoft TINYINT unsigned. PG SMALLINT accepts up to 32767.
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpEdge, int(30302), int16(255)).Scan(&affected); err != nil {
			t.Fatalf("edge max: %v", err)
		}
		if affected != 1 {
			t.Fatalf("edge max affected: got %d, want 1", affected)
		}

		var rZero, rMax int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidPutRcpEdge, 30301).Scan(&rZero); err != nil {
			t.Fatalf("verify edge zero: %v", err)
		}
		if rZero != 0 {
			t.Fatalf("edge zero round-trip: got %d, want 0", rZero)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT remain_count FROM user_recipe
			  WHERE char_id=$1 AND recipe_id=$2`,
			cidPutRcpEdge, 30302).Scan(&rMax); err != nil {
			t.Fatalf("verify edge max: %v", err)
		}
		if rMax != 255 {
			t.Fatalf("edge max round-trip: got %d, want 255", rMax)
		}
	})

	t.Run("missing user_data: PutRecipe still succeeds (no FK pin)", func(t *testing.T) {
		// Bug-for-bug pin: NCSoft has no FK on user_recipe.char_id.
		// We can pin a recipe on a char that does not exist.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putrecipe",
			cidPutRcpOrphan, int(30401), int16(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow orphan: %v", err)
		}
		if affected != 1 {
			t.Fatalf("orphan affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_recipe WHERE char_id=$1`,
			cidPutRcpOrphan).Scan(&n); err != nil {
			t.Fatalf("count orphan: %v", err)
		}
		if n != 1 {
			t.Fatalf("orphan: got %d rows, want 1", n)
		}
	})
}
