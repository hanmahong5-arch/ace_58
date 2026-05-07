// Package database — integration test for aion_GetRecipeList.
//
// Returns (recipe_id, remain_count) for every recipe owned by char_id.
// No tombstone filter — even rows with remain_count=0 surface (client decides).
//
// Test matrix:
//   - owner with 3 recipes (one unlimited -1, one consumed 0, one finite) → all 3 surface
//   - owner with 0 recipes → 0 rows
//   - remain_count semantics (-1 unlimited / 0 consumed / >0 finite) round-trips
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidRcpA     = 9001910 // owner with 3 recipes (mixed remain_count)
	cidRcpEmpty = 9001911 // owner with 0 recipes
)

func getRecipeListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_recipe WHERE char_id BETWEEN 9001910 AND 9001919`); err != nil {
		t.Fatalf("getRecipeListCleanup user_recipe: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001910 AND 9001919`); err != nil {
		t.Fatalf("getRecipeListCleanup user_data: %v", err)
	}
}

func TestGetRecipeList(t *testing.T) {
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

	getRecipeListCleanup(t, ctx, pool)
	t.Cleanup(func() { getRecipeListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidRcpA, "RcpA"},
		{cidRcpEmpty, "RcpEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "rc_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	type seedRow struct {
		recipeID int32
		remain   int16
	}
	for _, r := range []seedRow{
		{30001, -1}, // unlimited (typical cooking)
		{30002, 0},  // consumed — must STILL surface (no filter)
		{30003, 5},  // finite charges
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_recipe(char_id, recipe_id, remain_count) VALUES ($1, $2, $3)`,
			cidRcpA, r.recipeID, r.remain); err != nil {
			t.Fatalf("seed (recipe=%d): %v", r.recipeID, err)
		}
	}

	t.Run("owner returns all recipes regardless of remain_count", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getrecipelist", cidRcpA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			recipeID int32
			remain   int16
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.recipeID, &o.remain); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("row count: got %d, want 3 (no tombstone filter)", len(got))
		}
		sort.Slice(got, func(i, j int) bool { return got[i].recipeID < got[j].recipeID })
		want := []out{{30001, -1}, {30002, 0}, {30003, 5}}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no recipes returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getrecipelist", cidRcpEmpty)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var n int
		for rs.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("empty owner: got %d rows, want 0", n)
		}
	})
}
