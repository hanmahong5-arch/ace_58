// Package database — integration test for aion_GetPromotionCoolTimeList.
//
// Per-character promotion cooldown hydration. Reads zero-or-more rows
// from user_promotion_cooltime keyed by char_id, returning the 5
// (promotion_id, last_promotion_time, received_item_count,
//  cycle_received_item_count, cycle_next_reset_time) shape.
//
// Test matrix:
//   - char with 0 promotions  → 0 rows
//   - char with 1 promotion   → 1 row, all 5 fields round-trip
//   - char with 3 promotions  → 3 rows, every promotion_id present
//   - neighbour char's rows do NOT leak
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidPromoListEmpty = 9001980 // hydration with no rows yet
	cidPromoListOne   = 9001981 // one promotion in flight
	cidPromoListMany  = 9001982 // three concurrent promotions
	cidPromoListOther = 9001983 // neighbour, must not leak
)

func getPromotionCoolTimeListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_promotion_cooltime WHERE char_id BETWEEN 9001980 AND 9001989`); err != nil {
		t.Fatalf("getPromotionCoolTimeListCleanup user_promotion_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001980 AND 9001989`); err != nil {
		t.Fatalf("getPromotionCoolTimeListCleanup user_data: %v", err)
	}
}

func TestGetPromotionCoolTimeList(t *testing.T) {
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

	getPromotionCoolTimeListCleanup(t, ctx, pool)
	t.Cleanup(func() { getPromotionCoolTimeListCleanup(t, context.Background(), pool) })

	// user_data seeds (FK isn't enforced but a real call goes through PutChar).
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidPromoListEmpty, "pE"},
		{cidPromoListOne, "p1"},
		{cidPromoListMany, "pM"},
		{cidPromoListOther, "pO"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "pct_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Char One: a single promotion row with non-default values across all 4
	// cooldown columns to prove every column round-trips, not just an alias.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_promotion_cooltime(
		    char_id, promotion_id, last_promotion_time, received_item_count,
		    cycle_received_item_count, cycle_next_reset_time)
		 VALUES ($1, 100, 1714000000, 7, 3, 1714086400)`,
		cidPromoListOne); err != nil {
		t.Fatalf("seed One: %v", err)
	}

	// Char Many: 3 promotions, distinct ids and distinct value tuples.
	type seedRow struct {
		promoID            int16
		lastPromotionTime  int
		receivedCount      int
		cycleReceivedCount int
		cycleNextReset     int
	}
	seedsMany := []seedRow{
		{promoID: 200, lastPromotionTime: 1700000001, receivedCount: 1, cycleReceivedCount: 0, cycleNextReset: 1700086401},
		{promoID: 201, lastPromotionTime: 1700000002, receivedCount: 2, cycleReceivedCount: 1, cycleNextReset: 1700086402},
		{promoID: 202, lastPromotionTime: 1700000003, receivedCount: 3, cycleReceivedCount: 2, cycleNextReset: 1700086403},
	}
	for _, s := range seedsMany {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_promotion_cooltime(
			    char_id, promotion_id, last_promotion_time, received_item_count,
			    cycle_received_item_count, cycle_next_reset_time)
			 VALUES ($1, $2, $3, $4, $5, $6)`,
			cidPromoListMany, s.promoID, s.lastPromotionTime,
			s.receivedCount, s.cycleReceivedCount, s.cycleNextReset); err != nil {
			t.Fatalf("seed Many promo=%d: %v", s.promoID, err)
		}
	}

	// Neighbour must not leak when querying char Many.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_promotion_cooltime(
		    char_id, promotion_id, last_promotion_time, received_item_count,
		    cycle_received_item_count, cycle_next_reset_time)
		 VALUES ($1, 999, 1700099999, 99, 99, 1700099999)`,
		cidPromoListOther); err != nil {
		t.Fatalf("seed Other: %v", err)
	}

	t.Run("char with 0 promotions returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpromotioncooltimelist", cidPromoListEmpty)
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

	t.Run("char with 1 promotion returns 1 row, all fields round-trip", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpromotioncooltimelist", cidPromoListOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n           int
			promoID     int16
			lastTime    int
			recvCount   int
			cycRecv     int
			cycReset    int
		)
		for rows.Next() {
			if err := rows.Scan(&promoID, &lastTime, &recvCount, &cycRecv, &cycReset); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("one: got %d rows, want 1", n)
		}
		if promoID != 100 || lastTime != 1714000000 || recvCount != 7 ||
			cycRecv != 3 || cycReset != 1714086400 {
			t.Fatalf("one row: got (%d, %d, %d, %d, %d), want (100, 1714000000, 7, 3, 1714086400)",
				promoID, lastTime, recvCount, cycRecv, cycReset)
		}
	})

	t.Run("char with 3 promotions returns 3 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpromotioncooltimelist", cidPromoListMany)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		type out struct {
			promoID     int16
			lastTime    int
			recvCount   int
			cycRecv     int
			cycReset    int
		}
		var got []out
		for rows.Next() {
			var o out
			if err := rows.Scan(&o.promoID, &o.lastTime, &o.recvCount, &o.cycRecv, &o.cycReset); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("many: got %d rows, want 3", len(got))
		}
		// Sort by promotion_id; PG SELECT order is implementation-dependent
		// without ORDER BY, and the SP intentionally does not impose one.
		sort.Slice(got, func(i, j int) bool { return got[i].promoID < got[j].promoID })
		want := []out{
			{200, 1700000001, 1, 0, 1700086401},
			{201, 1700000002, 2, 1, 1700086402},
			{202, 1700000003, 3, 2, 1700086403},
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got=%+v, want=%+v", i, got[i], w)
			}
		}
		// Neighbour 999 must NOT appear.
		for _, o := range got {
			if o.promoID == 999 {
				t.Fatalf("neighbour leak: promo 999 found in Many's result")
			}
		}
	})
}
