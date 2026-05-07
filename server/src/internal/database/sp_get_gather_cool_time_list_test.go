// Package database — integration test for aion_GetGatherCoolTimeList.
//
// Returns (cooltime_id, expire_cooltime) for every gather-class throttle the
// char has triggered. NCSoft semantics: SP returns all rows regardless of
// expiry — client/Lua filters expire_cooltime <= now() to mark as ready.
// Pairs with aion_PutGatherCoolTime (00173) producer.
//
// Test matrix:
//   - owner with 3 cooldowns (one expired, one future, one zero) → all 3 surface
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
	cidGctA     = 9001945 // owner with 3 gather cooldowns (mixed times)
	cidGctEmpty = 9001946 // owner with 0 cooldowns
)

func getGatherCoolTimeListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_gather_cooltime WHERE char_id BETWEEN 9001945 AND 9001949`); err != nil {
		t.Fatalf("getGatherCoolTimeListCleanup user_gather_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001945 AND 9001949`); err != nil {
		t.Fatalf("getGatherCoolTimeListCleanup user_data: %v", err)
	}
}

func TestGetGatherCoolTimeList(t *testing.T) {
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

	getGatherCoolTimeListCleanup(t, ctx, pool)
	t.Cleanup(func() { getGatherCoolTimeListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidGctA, "GctA"},
		{cidGctEmpty, "GctEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "gc_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	type seedRow struct {
		cooltimeID int32
		expire     int64
	}
	// Distinctive 64-bit values to verify bigint precision survives.
	for _, r := range []seedRow{
		{50001, 1700000000000}, // expired in the past
		{50002, 1900000000000}, // far future
		{50003, 0},             // never triggered (still surfaces — no filter)
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_gather_cooltime(char_id, cooltime_id, expire_cooltime)
			 VALUES ($1, $2, $3)`,
			cidGctA, r.cooltimeID, r.expire); err != nil {
			t.Fatalf("seed (cooltime_id=%d): %v", r.cooltimeID, err)
		}
	}

	t.Run("owner returns all cooldowns regardless of expiry", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getgathercooltimelist", cidGctA)
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
			{50001, 1700000000000},
			{50002, 1900000000000},
			{50003, 0},
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no cooldowns returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getgathercooltimelist", cidGctEmpty)
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
