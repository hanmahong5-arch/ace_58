// Package database — integration test for aion_GetUserBMPackList.
//
// Returns (pack_type, expiration_time) rows filtered by (char_id, pack_state).
// Verifies: missing char → 0 rows, state mismatch → 0 rows, multiple types in
// the requested state → all rows ordered by pack_type, neighbour char isolation.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidBMListEmpty   = 9001200 // has rows but only in state=2; query state=1 → 0 rows
	cidBMListMulti   = 9001201 // 3 rows in state=1, 1 row in state=2
	cidBMListOther   = 9001202 // neighbour
	cidBMListMissing = 9001299 // never inserted
)

func userBMPackListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_bm_pack WHERE char_id BETWEEN 9001200 AND 9001299`); err != nil {
		t.Fatalf("userBMPackListCleanup user_bm_pack: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001200 AND 9001299`); err != nil {
		t.Fatalf("userBMPackListCleanup user_data: %v", err)
	}
}

func TestGetUserBMPackList(t *testing.T) {
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

	userBMPackListCleanup(t, ctx, pool)
	t.Cleanup(func() { userBMPackListCleanup(t, context.Background(), pool) })

	for _, cid := range []int{cidBMListEmpty, cidBMListMulti, cidBMListOther} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'bm_'||$1::TEXT, 'bu_'||$1::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	// cidBMListEmpty has only a state=2 row.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_bm_pack(char_id, pack_type, pack_state, expiration_time)
		 VALUES ($1, 10, 2, 1700000000)`,
		cidBMListEmpty); err != nil {
		t.Fatalf("seed empty: %v", err)
	}

	// cidBMListMulti: 3 state=1 rows (types 5, 1, 8 inserted scrambled) + 1 state=2 row.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_bm_pack(char_id, pack_type, pack_state, expiration_time) VALUES
		 ($1, 5, 1, 1701000000),
		 ($1, 1, 1, 1700500000),
		 ($1, 8, 1, 1702000000),
		 ($1, 9, 2, 1703000000)`,
		cidBMListMulti); err != nil {
		t.Fatalf("seed multi: %v", err)
	}

	// Neighbour with one state=1 row.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_bm_pack(char_id, pack_type, pack_state, expiration_time)
		 VALUES ($1, 99, 1, 1709999999)`,
		cidBMListOther); err != nil {
		t.Fatalf("seed other: %v", err)
	}

	t.Run("missing char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserbmpacklist", cidBMListMissing, 1)
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

	t.Run("state mismatch returns 0 rows", func(t *testing.T) {
		// cidBMListEmpty has only state=2 rows; query for state=1 → 0.
		rows, err := pool.CallSP(ctx, "aion_getuserbmpacklist", cidBMListEmpty, 1)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("state mismatch: got %d rows, want 0", n)
		}
	})

	t.Run("multi rows ordered by pack_type", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserbmpacklist", cidBMListMulti, 1)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		type row struct {
			packType int16
			expire   int32
		}
		var got []row
		for rows.Next() {
			var r row
			if err := rows.Scan(&r.packType, &r.expire); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, r)
		}
		want := []row{
			{packType: 1, expire: 1700500000},
			{packType: 5, expire: 1701000000},
			{packType: 8, expire: 1702000000},
		}
		if len(got) != len(want) {
			t.Fatalf("multi: len=%d, want %d (got=%v)", len(got), len(want), got)
		}
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("multi[%d]: got=%+v, want=%+v", i, got[i], want[i])
			}
		}
	})

	t.Run("neighbour rows do not leak", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserbmpacklist", cidBMListOther, 1)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n      int
			pType  int16
			expire int32
		)
		for rows.Next() {
			if err := rows.Scan(&pType, &expire); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || pType != 99 {
			t.Fatalf("other: n=%d type=%d, want n=1 type=99", n, pType)
		}
	})
}
