// Package database — integration test for aion_GetSkillSkinList.
//
// Returns (skill_skin_id, expire_time, use_skin) for char's owned skill skins
// where expire_time > 0 (NCSoft soft-expiry tombstone filter).
//
// Test matrix:
//   - owner with 2 active + 1 tombstone (expire_time=0): only the 2 actives surface
//   - owner with no rows: 0 rows
//   - column projection (use_skin / expire_time bigint) round-trips
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidSksA     = 9001934 // owner with 2 active + 1 tombstone
	cidSksEmpty = 9001935 // owner with 0 rows
)

func getSkillSkinListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_skill_skin WHERE char_id BETWEEN 9001934 AND 9001939`); err != nil {
		t.Fatalf("getSkillSkinListCleanup user_skill_skin: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001934 AND 9001939`); err != nil {
		t.Fatalf("getSkillSkinListCleanup user_data: %v", err)
	}
}

func TestGetSkillSkinList(t *testing.T) {
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

	getSkillSkinListCleanup(t, ctx, pool)
	t.Cleanup(func() { getSkillSkinListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidSksA, "SksA"},
		{cidSksEmpty, "SksEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "sk_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	type seedRow struct {
		skinID  int32
		expire  int64
		useSkin int16
	}
	for _, r := range []seedRow{
		{50001, 1700000000, 1}, // active equipped
		{50002, 1700001000, 0}, // active owned-not-equipped
		{50003, 0, 0},          // tombstone — must NOT surface
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_skill_skin(char_id, skill_skin_id, expire_time, use_skin)
			 VALUES ($1, $2, $3, $4)`,
			cidSksA, r.skinID, r.expire, r.useSkin); err != nil {
			t.Fatalf("seed (skin=%d): %v", r.skinID, err)
		}
	}

	t.Run("owner with mixed actives + tombstone returns only actives", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getskillskinlist", cidSksA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			skinID  int32
			expire  int64
			useSkin int16
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.skinID, &o.expire, &o.useSkin); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 2 {
			t.Fatalf("row count: got %d, want 2 (tombstone expire_time=0 must be filtered)", len(got))
		}
		// ORDER BY skill_skin_id ASC → 50001, 50002.
		sort.Slice(got, func(i, j int) bool { return got[i].skinID < got[j].skinID })
		want := []out{
			{50001, 1700000000, 1},
			{50002, 1700001000, 0},
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no skins returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getskillskinlist", cidSksEmpty)
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
