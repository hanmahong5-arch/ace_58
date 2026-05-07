// Package database — integration test for aion_GetCombineCoolTimeList.
//
// Returns (cooltime_id, expire_cooltime) for every combine-class throttle the
// char has ever triggered. NCSoft semantics: SP returns all rows regardless of
// expiry — client/Lua filters expire_cooltime <= now() to mark as ready.
//
// Test matrix:
//   - owner with 3 cooldowns (one expired in past, one future, one zero) → all 3 surface
//   - owner with 0 cooldowns → 0 rows
//   - bigint precision (millisecond timestamps) round-trips
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidCctA     = 9001932 // owner with 3 combine cooldowns (mixed times)
	cidCctEmpty = 9001933 // owner with 0 cooldowns
)

func getCombineCoolTimeListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_combine_cooltime WHERE char_id BETWEEN 9001932 AND 9001939`); err != nil {
		t.Fatalf("getCombineCoolTimeListCleanup user_combine_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001932 AND 9001939`); err != nil {
		t.Fatalf("getCombineCoolTimeListCleanup user_data: %v", err)
	}
}

func TestGetCombineCoolTimeList(t *testing.T) {
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

	getCombineCoolTimeListCleanup(t, ctx, pool)
	t.Cleanup(func() { getCombineCoolTimeListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidCctA, "CctA"},
		{cidCctEmpty, "CctEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "cc_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	type seedRow struct {
		cooltimeID int32
		expire     int64
	}
	// Use distinctive 64-bit values to verify bigint precision survives.
	for _, r := range []seedRow{
		{40001, 1700000000000}, // expired in the past (> 2023)
		{40002, 1900000000000}, // far future
		{40003, 0},             // never triggered (still surfaces — no filter)
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_combine_cooltime(char_id, cooltime_id, expire_cooltime)
			 VALUES ($1, $2, $3)`,
			cidCctA, r.cooltimeID, r.expire); err != nil {
			t.Fatalf("seed (cooltime_id=%d): %v", r.cooltimeID, err)
		}
	}

	t.Run("owner returns all cooldowns regardless of expiry", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getcombinecooltimelist", cidCctA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			cooltimeID int32
			expire     int64
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.cooltimeID, &o.expire); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("row count: got %d, want 3 (no expiry filter)", len(got))
		}
		sort.Slice(got, func(i, j int) bool { return got[i].cooltimeID < got[j].cooltimeID })
		want := []out{
			{40001, 1700000000000},
			{40002, 1900000000000},
			{40003, 0},
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no cooldowns returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getcombinecooltimelist", cidCctEmpty)
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
