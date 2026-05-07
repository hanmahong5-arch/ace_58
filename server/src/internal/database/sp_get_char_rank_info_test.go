// Package database — integration test for aion_GetCharRankInfo.
//
// Read-only SP: returns six rank columns for one (char_id, rank_id) tuple.
// 0 rows when the row is absent (NCSoft never raises a "not-found" error;
// callers infer absence from row count).
//
// Test matrix:
//   - happy path: existing tuple → 1 row, all 6 columns round-trip byte-equal
//   - missing tuple: char exists in user_rank under a different rank_id only
//     → still 0 rows (filter is composite)
//   - absent char (no row at all) → 0 rows
//   - same char, two distinct rank_ids: each query returns its own row only
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidRankA       = 9520031
	cidRankB       = 9520032
	cidRankAbsent  = 9520033
)

func getCharRankInfoCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_rank WHERE char_id BETWEEN 9520031 AND 9520099`); err != nil {
		t.Fatalf("getCharRankInfoCleanup user_rank: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9520031 AND 9520099`); err != nil {
		t.Fatalf("getCharRankInfoCleanup user_data: %v", err)
	}
}

func TestGetCharRankInfo(t *testing.T) {
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

	getCharRankInfoCleanup(t, ctx, pool)
	t.Cleanup(func() { getCharRankInfoCleanup(t, context.Background(), pool) })

	// Seed parent chars + assorted rank rows.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidRankA, "RankA"},
		{cidRankB, "RankB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "rank_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Seed user_rank rows. Picked values that are unambiguous in INT round-trip.
	type rankSeed struct {
		charID, rankID, gRank, point, lRank, lPoint, bRank, bPoint int
	}
	for _, r := range []rankSeed{
		// cidRankA in two distinct rank_ids — coexistence test.
		{cidRankA, 1, 42, 10000, 50, 9500, 12, 15000},
		{cidRankA, 7, 1, 99999, 1, 99999, 1, 99999},
		// cidRankB only in rank_id=1.
		{cidRankB, 1, 100, 5000, 110, 4500, 80, 7000},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_rank(char_id, rank_id, global_ranking, point,
			                       last_ranking, last_point, best_ranking, best_point)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
			r.charID, r.rankID, r.gRank, r.point, r.lRank, r.lPoint, r.bRank, r.bPoint,
		); err != nil {
			t.Fatalf("seed user_rank %d/%d: %v", r.charID, r.rankID, err)
		}
	}

	t.Run("happy path: existing tuple → 1 row with byte-equal columns", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getcharrankinfo", cidRankA, 1)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		var (
			gotCount                                          int
			gRank, point, lRank, lPoint, bRank, bPoint        int32
		)
		for rs.Next() {
			gotCount++
			if err := rs.Scan(&gRank, &point, &lRank, &lPoint, &bRank, &bPoint); err != nil {
				t.Fatalf("Scan: %v", err)
			}
		}
		if err := rs.Err(); err != nil {
			t.Fatalf("rows.Err: %v", err)
		}
		if gotCount != 1 {
			t.Fatalf("rows: got %d, want 1", gotCount)
		}
		if gRank != 42 || point != 10000 || lRank != 50 || lPoint != 9500 ||
			bRank != 12 || bPoint != 15000 {
			t.Fatalf("columns: got %d/%d/%d/%d/%d/%d, want 42/10000/50/9500/12/15000",
				gRank, point, lRank, lPoint, bRank, bPoint)
		}
	})

	t.Run("char exists in different rank_id only → 0 rows for asked rank", func(t *testing.T) {
		// cidRankB is seeded in rank_id=1 only. Ask for rank_id=99 → must get 0.
		rs, err := pool.CallSP(ctx, "aion_getcharrankinfo", cidRankB, 99)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var n int
		for rs.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("wrong rank_id leaked: got %d rows, want 0", n)
		}
	})

	t.Run("absent char → 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getcharrankinfo", cidRankAbsent, 1)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var n int
		for rs.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("absent char: got %d rows, want 0", n)
		}
	})

	t.Run("same char, two rank_ids: each surfaces only its own row", func(t *testing.T) {
		// rank_id=7 uniquely surfaces (1, 99999, 1, 99999, 1, 99999).
		rs, err := pool.CallSP(ctx, "aion_getcharrankinfo", cidRankA, 7)
		if err != nil {
			t.Fatalf("CallSP rank=7: %v", err)
		}
		defer rs.Close()

		var (
			gotCount                                          int
			gRank, point, lRank, lPoint, bRank, bPoint        int32
		)
		for rs.Next() {
			gotCount++
			if err := rs.Scan(&gRank, &point, &lRank, &lPoint, &bRank, &bPoint); err != nil {
				t.Fatalf("Scan: %v", err)
			}
		}
		if gotCount != 1 {
			t.Fatalf("rows: got %d, want 1", gotCount)
		}
		if gRank != 1 || point != 99999 || lRank != 1 || lPoint != 99999 ||
			bRank != 1 || bPoint != 99999 {
			t.Fatalf("rank_id=7 leaked rank_id=1 row: got %d/%d/%d/%d/%d/%d",
				gRank, point, lRank, lPoint, bRank, bPoint)
		}
	})
}
