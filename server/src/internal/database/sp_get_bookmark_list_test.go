// Package database — integration test for aion_GetBookmarkList.
//
// Returns (bookmark, world, x, y, z) for the char's saved teleport favourites.
// No filter beyond char_id — soft-delete is "row missing", not a tombstone.
//
// Test matrix:
//   - owner with 3 bookmarks → all 3 surface in PK order
//   - owner with no bookmarks → 0 rows
//   - column projection (world / xyz) round-trips byte-equal
package database

import (
	"context"
	"math"
	"testing"
	"time"
)

const (
	cidBkA     = 9001903 // owner with 3 bookmarks
	cidBkEmpty = 9001904 // owner with 0 bookmarks
)

func getBookmarkListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM bookmark WHERE char_id BETWEEN 9001903 AND 9001909`); err != nil {
		t.Fatalf("getBookmarkListCleanup bookmark: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001903 AND 9001909`); err != nil {
		t.Fatalf("getBookmarkListCleanup user_data: %v", err)
	}
}

func TestGetBookmarkList(t *testing.T) {
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

	getBookmarkListCleanup(t, ctx, pool)
	t.Cleanup(func() { getBookmarkListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidBkA, "BkA"},
		{cidBkEmpty, "BkEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "bk_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// 3 distinct slots — must surface in slot-asc order.
	type seedRow struct {
		slot    int16
		world   int32
		x, y, z float32
	}
	for _, r := range []seedRow{
		{0, 220020000, 1234.5, 4321.25, 96.5},   // Sanctum
		{2, 210020000, 1500.0, 1500.0, 100.0},   // Pandaemonium
		{1, 210060000, 256.125, 512.5, 50.0625}, // out-of-order to verify ORDER BY
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO bookmark(char_id, bookmark, world, x, y, z) VALUES ($1, $2, $3, $4, $5, $6)`,
			cidBkA, r.slot, r.world, r.x, r.y, r.z); err != nil {
			t.Fatalf("seed slot=%d: %v", r.slot, err)
		}
	}

	t.Run("owner with bookmarks returns rows in slot-asc order", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getbookmarklist", cidBkA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			slot    int16
			world   int32
			x, y, z float32
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.slot, &o.world, &o.x, &o.y, &o.z); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("row count: got %d, want 3", len(got))
		}
		// Server sorts ASC by bookmark slot → 0, 1, 2.
		want := []out{
			{0, 220020000, 1234.5, 4321.25, 96.5},
			{1, 210060000, 256.125, 512.5, 50.0625},
			{2, 210020000, 1500.0, 1500.0, 100.0},
		}
		for i, w := range want {
			if got[i].slot != w.slot || got[i].world != w.world {
				t.Fatalf("row[%d] hdr: got %+v, want %+v", i, got[i], w)
			}
			// Floats picked to be representable byte-exact in float32.
			if math.Abs(float64(got[i].x-w.x)) > 0 ||
				math.Abs(float64(got[i].y-w.y)) > 0 ||
				math.Abs(float64(got[i].z-w.z)) > 0 {
				t.Fatalf("row[%d] xyz round-trip: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no bookmarks returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getbookmarklist", cidBkEmpty)
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
