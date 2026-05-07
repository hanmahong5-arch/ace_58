// Package database — integration test for aion_GetItemSealInfo.
//
// Reads sealed-item rows for a given char_id, returning (id, sealState,
// sealExpiredTime). Sister of 00211 SetItemSealInfo / 00213 DeleteItemSealInfo.
//
// Test matrix:
//   - empty char (no sealed items) returns 0 rows
//   - single seal returns 1 row with full payload round-trip
//   - multi-seal char returns N rows; values match per-id state
//   - neighbour isolation: only the queried char's seals appear
//   - expired seals still appear (no server-side expiry filter — bug-for-bug)
//
// char_id band: 9_530_030..9_530_039 (R15 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidGetSealEmpty = 9530030 // seeded but no seals → empty result
	cidGetSealOne   = 9530031 // exactly 1 seal
	cidGetSealMulti = 9530032 // 3 seals
	cidGetSealOther = 9530033 // neighbour, must not bleed into others
	itemGetSealM1   = int64(8000010001)
	itemGetSealM2   = int64(8000010002)
	itemGetSealM3   = int64(8000010003)
	itemGetSealOne  = int64(8000010100)
	itemGetSealOther = int64(8000010200)
)

func getItemSealInfoCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_sealed WHERE id BETWEEN 8000010001 AND 8000010299`); err != nil {
		t.Fatalf("getItemSealInfoCleanup user_item_sealed: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9530030 AND 9530039`); err != nil {
		t.Fatalf("getItemSealInfoCleanup user_data: %v", err)
	}
}

func TestGetItemSealInfo(t *testing.T) {
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

	getItemSealInfoCleanup(t, ctx, pool)
	t.Cleanup(func() { getItemSealInfoCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidGetSealEmpty, "GetEmpty"},
		{cidGetSealOne, "GetOne"},
		{cidGetSealMulti, "GetMulti"},
		{cidGetSealOther, "GetOther"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "gs_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Seed seals via SetItemSealInfo so the data path is identical to prod.
	// cidGetSealOne: 1 seal.
	if err := pool.CallSPExec(ctx, "aion_setitemsealinfo",
		cidGetSealOne, itemGetSealOne, int(1), int(1700000111)); err != nil {
		t.Fatalf("seed seal one: %v", err)
	}
	// cidGetSealMulti: 3 seals (one with sealState=2, one expired in the past).
	for _, sd := range []struct {
		id    int64
		state int
		exp   int
	}{
		{itemGetSealM1, 1, 1700001000}, // active
		{itemGetSealM2, 2, 1700002000}, // cooldown
		{itemGetSealM3, 1, 100},        // already expired (epoch 100 = 1970-01-01)
	} {
		if err := pool.CallSPExec(ctx, "aion_setitemsealinfo",
			cidGetSealMulti, sd.id, sd.state, sd.exp); err != nil {
			t.Fatalf("seed seal multi id=%d: %v", sd.id, err)
		}
	}
	// cidGetSealOther: 1 seal — must NOT appear in others' results.
	if err := pool.CallSPExec(ctx, "aion_setitemsealinfo",
		cidGetSealOther, itemGetSealOther, int(1), int(1700000999)); err != nil {
		t.Fatalf("seed seal other: %v", err)
	}

	t.Run("empty char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getitemsealinfo", cidGetSealEmpty)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var cnt int
		for rows.Next() {
			cnt++
		}
		if cnt != 0 {
			t.Fatalf("empty char: got %d rows, want 0", cnt)
		}
	})

	t.Run("single seal round-trips full payload", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getitemsealinfo", cidGetSealOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			gotID         int64
			gotSeal, gotExp int
		)
		var n int
		for rows.Next() {
			if err := rows.Scan(&gotID, &gotSeal, &gotExp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("single: got %d rows, want 1", n)
		}
		if gotID != itemGetSealOne || gotSeal != 1 || gotExp != 1700000111 {
			t.Fatalf("single payload: id=%d state=%d exp=%d, want %d/1/1700000111",
				gotID, gotSeal, gotExp, itemGetSealOne)
		}
	})

	t.Run("multi seal returns N rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getitemsealinfo", cidGetSealMulti)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		// Map id → (state, expired) so test order-agnostic.
		type sealRow struct {
			state, exp int
		}
		got := map[int64]sealRow{}
		for rows.Next() {
			var (
				id          int64
				state, exp  int
			)
			if err := rows.Scan(&id, &state, &exp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got[id] = sealRow{state, exp}
		}
		if len(got) != 3 {
			t.Fatalf("multi: got %d rows, want 3", len(got))
		}
		want := map[int64]sealRow{
			itemGetSealM1: {1, 1700001000},
			itemGetSealM2: {2, 1700002000},
			itemGetSealM3: {1, 100},
		}
		for k, v := range want {
			if got[k] != v {
				t.Fatalf("multi id=%d: got %+v, want %+v", k, got[k], v)
			}
		}
	})

	t.Run("expired seal still appears (bug-for-bug — no server-side filter)", func(t *testing.T) {
		// itemGetSealM3 has sealExpiredTime=100 (1970). NCSoft does not filter
		// expired seals server-side; the application layer must interpret expiry.
		// We verify itemGetSealM3 is present in the multi-result — already
		// covered by the previous subtest's want-map, but spell it out so a
		// future contributor doesn't add a "WHERE expired > NOW()" filter
		// thinking it's a bug.
		rows, err := pool.CallSP(ctx, "aion_getitemsealinfo", cidGetSealMulti)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var sawExpired bool
		for rows.Next() {
			var (
				id          int64
				state, exp  int
			)
			if err := rows.Scan(&id, &state, &exp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if id == itemGetSealM3 && exp == 100 {
				sawExpired = true
			}
		}
		if !sawExpired {
			t.Fatalf("expired seal vanished — server-side filter introduced? Bug-for-bug pin")
		}
	})

	t.Run("neighbour isolation: other char's seal does not appear", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getitemsealinfo", cidGetSealOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var leakedOther bool
		for rows.Next() {
			var (
				id          int64
				state, exp  int
			)
			if err := rows.Scan(&id, &state, &exp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if id == itemGetSealOther {
				leakedOther = true
			}
		}
		if leakedOther {
			t.Fatalf("isolation: other-char seal leaked into result of cidGetSealOne")
		}
	})
}
