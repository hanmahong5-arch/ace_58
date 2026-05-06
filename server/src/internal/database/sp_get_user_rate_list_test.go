// Package database — integration test for aion_GetUserRateList.
//
// Returns the full set of (rate_id, mu, sigma, update_cnt) rows for one char.
// Verifies: no-rate char → 0 rows, single-bucket char → 1 row exact match,
// multi-bucket char → all rows ordered by rate_id, neighbour char's rows
// remain isolated.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidRateEmpty   = 9001100 // never had a match
	cidRateSingle  = 9001101 // one rate bucket only
	cidRateMulti   = 9001102 // three rate buckets
	cidRateOther   = 9001103 // a neighbour, used for isolation check
	cidRateMissing = 9001199 // never inserted
)

func userRateCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_rate WHERE char_id BETWEEN 9001100 AND 9001199`); err != nil {
		t.Fatalf("userRateCleanup user_rate: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001100 AND 9001199`); err != nil {
		t.Fatalf("userRateCleanup user_data: %v", err)
	}
}

func TestGetUserRateList(t *testing.T) {
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

	userRateCleanup(t, ctx, pool)
	t.Cleanup(func() { userRateCleanup(t, context.Background(), pool) })

	for _, cid := range []int{cidRateEmpty, cidRateSingle, cidRateMulti, cidRateOther} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'rate_'||$1::TEXT, 'ru_'||$1::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	// Seed: single bucket on cidRateSingle (rate_id=1, mu=27.5, sigma=6.0, cnt=42).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_rate(char_id, rate_id, mu, sigma, update_cnt)
		 VALUES ($1, 1, 27.5, 6.0, 42)`,
		cidRateSingle); err != nil {
		t.Fatalf("seed single: %v", err)
	}

	// Multi-bucket: insert rate_id 3, 1, 2 in scrambled order to test ORDER BY.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_rate(char_id, rate_id, mu, sigma, update_cnt) VALUES
		 ($1, 3, 22.0, 7.5,  10),
		 ($1, 1, 25.0, 8.333, 0),
		 ($1, 2, 30.0, 4.0,  99)`,
		cidRateMulti); err != nil {
		t.Fatalf("seed multi: %v", err)
	}

	// Neighbour with one row — must NOT leak into other char's results.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_rate(char_id, rate_id, mu, sigma, update_cnt) VALUES ($1, 5, 99.0, 1.0, 1)`,
		cidRateOther); err != nil {
		t.Fatalf("seed other: %v", err)
	}

	t.Run("missing char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserratelist", cidRateMissing)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing: got %d rows, want 0", n)
		}
	})

	t.Run("char without rate history returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserratelist", cidRateEmpty)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("empty: got %d rows, want 0", n)
		}
	})

	t.Run("single bucket returns one row with exact values", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserratelist", cidRateSingle)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n        int
			rateID   int
			mu, sig  float32
			updCnt   int
		)
		for rows.Next() {
			if err := rows.Scan(&rateID, &mu, &sig, &updCnt); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || rateID != 1 || mu != 27.5 || sig != 6.0 || updCnt != 42 {
			t.Fatalf("single: n=%d rate=%d mu=%v sigma=%v cnt=%d, want n=1 rate=1 mu=27.5 sigma=6.0 cnt=42",
				n, rateID, mu, sig, updCnt)
		}
	})

	t.Run("multi bucket returns rows ordered by rate_id", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserratelist", cidRateMulti)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		type rateRow struct {
			rateID int
			mu     float32
			sigma  float32
			cnt    int
		}
		var got []rateRow
		for rows.Next() {
			var r rateRow
			if err := rows.Scan(&r.rateID, &r.mu, &r.sigma, &r.cnt); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, r)
		}
		want := []rateRow{
			{rateID: 1, mu: 25.0, sigma: 8.333, cnt: 0},
			{rateID: 2, mu: 30.0, sigma: 4.0, cnt: 99},
			{rateID: 3, mu: 22.0, sigma: 7.5, cnt: 10},
		}
		if len(got) != len(want) {
			t.Fatalf("multi: len=%d, want %d (rows=%v)", len(got), len(want), got)
		}
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("multi[%d]: got=%+v, want=%+v", i, got[i], want[i])
			}
		}
	})

	t.Run("neighbour char's rows do not leak", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserratelist", cidRateOther)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 1 {
			t.Fatalf("other: n=%d, want 1 (only own row)", n)
		}
	})
}
