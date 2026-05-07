// Package database — integration test for aion_GetCustomAnimationList.
//
// Returns (animation_id, animation_type, expire_time, use_state) for the
// char's owned custom animations where expire_time > 0 (NCSoft soft-expiry
// tombstone filter).
//
// Test matrix:
//   - owner with 2 active + 1 tombstone (expire_time=0): only the 2 actives surface
//   - owner with no rows: 0 rows
//   - column projection (use_state / animation_type) round-trips
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidAnimA     = 9001970 // owner with 2 active + 1 tombstone
	cidAnimEmpty = 9001971 // owner with 0 rows
)

func getCustomAnimationListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_custom_animation WHERE char_id BETWEEN 9001970 AND 9001999`); err != nil {
		t.Fatalf("getCustomAnimationListCleanup uca: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001970 AND 9001999`); err != nil {
		t.Fatalf("getCustomAnimationListCleanup user_data: %v", err)
	}
}

func TestGetCustomAnimationList(t *testing.T) {
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

	getCustomAnimationListCleanup(t, ctx, pool)
	t.Cleanup(func() { getCustomAnimationListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidAnimA, "AnimA"},
		{cidAnimEmpty, "AnimEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "an_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// 3 rows — 2 active + 1 tombstone (expire_time=0 must be filtered out).
	type seedRow struct {
		animID     int
		animType   int16
		expireTime int64
		useState   int16
	}
	for _, r := range []seedRow{
		{12001, 0, 1700000000, 1}, // stance, equipped — active
		{12002, 1, 1700001000, 0}, // walk, owned-not-equipped — active
		{12003, 2, 0, 0},          // tombstone — must NOT surface
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_custom_animation(char_id, animation_id, animation_type, expire_time, use_state)
			 VALUES ($1, $2, $3, $4, $5)`,
			cidAnimA, r.animID, r.animType, r.expireTime, r.useState); err != nil {
			t.Fatalf("seed (anim=%d): %v", r.animID, err)
		}
	}

	t.Run("owner with mixed actives + tombstone returns only actives", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getcustomanimationlist", cidAnimA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			animID     int32
			animType   int16
			expireTime int64
			useState   int16
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.animID, &o.animType, &o.expireTime, &o.useState); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 2 {
			t.Fatalf("row count: got %d, want 2 (tombstone expire_time=0 must be filtered)", len(got))
		}
		// ORDER BY animation_id ASC → 12001, 12002.
		sort.Slice(got, func(i, j int) bool { return got[i].animID < got[j].animID })
		want := []out{
			{12001, 0, 1700000000, 1},
			{12002, 1, 1700001000, 0},
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no animations returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getcustomanimationlist", cidAnimEmpty)
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
