// Package database — integration test for aion_GetHouseObjectExtData.
//
// Returns sidecar usage counters for placeable house objects owned by one
// char_id. Verifies single-char filtering, multi-row hydration, neighbour
// isolation, and exact column round-trip across all 7 fields.
//
// Test matrix:
//   - char with 0 house objects        → 0 rows
//   - char with 2 house objects        → both rows surface, exact field match
//   - neighbour char's row does NOT leak when querying the test char
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidHouseExtA     = 9001957 // owner with 2 house objects
	cidHouseExtEmpty = 9001958 // owner with 0 house objects
	cidHouseExtOther = 9001959 // a third char, must not leak into A's results
)

func getHouseObjectExtDataCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM houseobject_extdata WHERE char_id BETWEEN 9001957 AND 9001969`); err != nil {
		t.Fatalf("getHouseObjectExtDataCleanup houseobject_extdata: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001957 AND 9001969`); err != nil {
		t.Fatalf("getHouseObjectExtDataCleanup user_data: %v", err)
	}
}

func TestGetHouseObjectExtData(t *testing.T) {
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

	getHouseObjectExtDataCleanup(t, ctx, pool)
	t.Cleanup(func() { getHouseObjectExtDataCleanup(t, context.Background(), pool) })

	for _, cid := range []int{cidHouseExtA, cidHouseExtEmpty, cidHouseExtOther} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1::INT, 'hext_'||$1::INT::TEXT, 'hxu_'||$1::INT::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	// Char A: two distinct house objects with non-trivial counter values.
	type extRow struct {
		objID, charID, accUseCnt   int
		nextResetTime              int64
		resourceID, accountID, dayCnt int
	}
	seedRowsA := []extRow{
		{objID: 700001, charID: cidHouseExtA, accUseCnt: 12, nextResetTime: 1714867200, resourceID: 188100001, accountID: 50001, dayCnt: 3},
		{objID: 700002, charID: cidHouseExtA, accUseCnt: 0, nextResetTime: 0, resourceID: 188100002, accountID: 50001, dayCnt: 0},
	}
	for _, r := range seedRowsA {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO houseobject_extdata(obj_id, char_id, accumulated_usecount,
				next_resettime_for_owner, resource_id, account_id, cur_owner_usecnt_per_day)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			r.objID, r.charID, r.accUseCnt, r.nextResetTime, r.resourceID, r.accountID, r.dayCnt); err != nil {
			t.Fatalf("seed objA %d: %v", r.objID, err)
		}
	}

	// Neighbour: must NOT surface in cidHouseExtA's results.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO houseobject_extdata(obj_id, char_id, accumulated_usecount,
			next_resettime_for_owner, resource_id, account_id, cur_owner_usecnt_per_day)
		 VALUES (700099, $1, 999, 0, 188100099, 50099, 99)`, cidHouseExtOther); err != nil {
		t.Fatalf("seed obj other: %v", err)
	}

	t.Run("char with no house objects returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_gethouseobjectextdata", cidHouseExtEmpty)
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

	t.Run("char with 2 objects returns both with exact field round-trip", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_gethouseobjectextdata", cidHouseExtA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		var got []extRow
		for rows.Next() {
			var r extRow
			if err := rows.Scan(&r.objID, &r.charID, &r.accUseCnt,
				&r.nextResetTime, &r.resourceID, &r.accountID, &r.dayCnt); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, r)
		}
		if len(got) != 2 {
			t.Fatalf("row count: got %d, want 2", len(got))
		}
		// SP has no ORDER BY — sort defensively for stable comparison.
		sort.Slice(got, func(i, j int) bool { return got[i].objID < got[j].objID })

		for i, want := range seedRowsA {
			if got[i] != want {
				t.Fatalf("row[%d]: got=%+v, want=%+v", i, got[i], want)
			}
		}
	})

	t.Run("isolation: neighbour's row does not leak", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_gethouseobjectextdata", cidHouseExtA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		for rows.Next() {
			var (
				objID, charID, accUseCnt, resourceID, accountID, dayCnt int
				nextResetTime                                           int64
			)
			if err := rows.Scan(&objID, &charID, &accUseCnt,
				&nextResetTime, &resourceID, &accountID, &dayCnt); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if charID != cidHouseExtA {
				t.Fatalf("leaked row: got char_id=%d (obj_id=%d), want only %d",
					charID, objID, cidHouseExtA)
			}
		}
	})
}
