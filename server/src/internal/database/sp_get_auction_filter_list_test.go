// Package database — integration test for aion_GetAuctionFilterList.
//
// Single-column projection: goodsid for every row matching `type = @type`.
// Server-wide table (no owner column). STABLE / read-only.
//
// Test matrix:
//   - existing type with N rows → N goodsids surface
//   - empty type → 0 rows
//   - bug-for-bug: rows under type=X are NOT visible to Get(type=Y)
//
// goodsID band: 95_60_041..95_60_059 (R18 batch — get subset).
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	goodsGfTyA1 = 95600141
	goodsGfTyA2 = 95600142
	goodsGfTyA3 = 95600143
	goodsGfTyB1 = 95600151 // belongs to a different type bucket
)

func getAuctionFilterCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_auctionfilter WHERE goodsID BETWEEN 95600141 AND 95600159`); err != nil {
		t.Fatalf("getAuctionFilterCleanup: %v", err)
	}
}

func TestGetAuctionFilterList(t *testing.T) {
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

	getAuctionFilterCleanup(t, ctx, pool)
	t.Cleanup(func() { getAuctionFilterCleanup(t, context.Background(), pool) })

	// Seed two type buckets:
	//   type=10 → 3 rows (goodsGfTyA1/A2/A3)
	//   type=11 → 1 row  (goodsGfTyB1)  — must NOT leak into type=10 result.
	for _, seed := range []struct {
		typ   int
		goods int
	}{
		{10, goodsGfTyA1},
		{10, goodsGfTyA2},
		{10, goodsGfTyA3},
		{11, goodsGfTyB1},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_auctionfilter(type, goodsID) VALUES ($1, $2)`,
			seed.typ, seed.goods); err != nil {
			t.Fatalf("seed (type=%d goodsID=%d): %v", seed.typ, seed.goods, err)
		}
	}

	t.Run("existing type with 3 rows surfaces all three", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getauctionfilterlist", int(10))
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		var got []int
		for rs.Next() {
			var g int
			if err := rs.Scan(&g); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, g)
		}
		if err := rs.Err(); err != nil {
			t.Fatalf("rows.Err: %v", err)
		}

		// Filter to band — there may be other rows from earlier scaffolds /
		// concurrent tests in the global table.
		want := []int{goodsGfTyA1, goodsGfTyA2, goodsGfTyA3}
		seen := map[int]bool{}
		for _, g := range got {
			if g >= 95600141 && g <= 95600159 {
				seen[g] = true
			}
		}
		if len(seen) != 3 {
			t.Fatalf("type=10 band: got %d distinct, want 3 (%v)", len(seen), got)
		}
		sort.Ints(want)
		for _, g := range want {
			if !seen[g] {
				t.Fatalf("missing goodsID %d in result", g)
			}
		}
	})

	t.Run("empty type returns 0 band rows", func(t *testing.T) {
		// Use a type bucket we never seeded with band-prefixed rows.
		rs, err := pool.CallSP(ctx, "aion_getauctionfilterlist", int(99999))
		if err != nil {
			t.Fatalf("CallSP empty: %v", err)
		}
		defer rs.Close()

		bandRows := 0
		for rs.Next() {
			var g int
			if err := rs.Scan(&g); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if g >= 95600141 && g <= 95600159 {
				bandRows++
			}
		}
		if bandRows != 0 {
			t.Fatalf("type=99999 band rows: got %d, want 0", bandRows)
		}
	})

	t.Run("bug-for-bug: rows under type=X invisible to Get(type=Y)", func(t *testing.T) {
		// goodsGfTyB1 was seeded with type=11. A Get(type=10) call must
		// NOT include it, even though Add(type=10, goodsGfTyB1) would
		// have been blocked by the goodsID-only EXISTS guard (00224).
		rs, err := pool.CallSP(ctx, "aion_getauctionfilterlist", int(10))
		if err != nil {
			t.Fatalf("CallSP cross-type: %v", err)
		}
		defer rs.Close()
		for rs.Next() {
			var g int
			if err := rs.Scan(&g); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if g == goodsGfTyB1 {
				t.Fatalf("goodsGfTyB1 (seeded under type=11) leaked into Get(type=10)")
			}
		}
	})
}
