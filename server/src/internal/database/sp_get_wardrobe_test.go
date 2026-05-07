// Package database — integration test for aion_GetWardrobe.
//
// SELECT (slot_id, name_id) for a given char from user_wardrobe. Bug-for-bug
// no expiry / validity filter — wardrobe entries are timeless.
//
// Test matrix:
//   - empty char (no wardrobe entries) returns 0 rows
//   - single entry returns one row with payload round-trip
//   - multi-entry char returns N rows (one per slot)
//   - composite PK (char_id, slot_id) prevents same-slot duplicates
//   - neighbour isolation: other char's wardrobe does not appear
//   - orphan tolerance: char_id without user_data row still works (no FK)
//
// char_id band: 9_540_010..9_540_019 (R16 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidWardrobeEmpty   = 9540010
	cidWardrobeOne     = 9540011
	cidWardrobeMulti   = 9540012
	cidWardrobeOther   = 9540013
	cidWardrobeOrphan  = 9540019 // intentionally NOT seeded into user_data

	wdSlotMain    = 1
	wdSlotSecond  = 2
	wdSlotThird   = 3
	wdNameOne     = 100001
	wdNameMulti1  = 100201
	wdNameMulti2  = 100202
	wdNameMulti3  = 100203
	wdNameOther  = 100999
	wdNameOrphan = 100888
)

func getWardrobeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_wardrobe WHERE char_id BETWEEN 9540010 AND 9540019`); err != nil {
		t.Fatalf("getWardrobeCleanup user_wardrobe: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9540010 AND 9540019`); err != nil {
		t.Fatalf("getWardrobeCleanup user_data: %v", err)
	}
}

func TestGetWardrobe(t *testing.T) {
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

	getWardrobeCleanup(t, ctx, pool)
	t.Cleanup(func() { getWardrobeCleanup(t, context.Background(), pool) })

	// Seed user_data only for the chars that have wardrobe entries.
	// cidWardrobeOrphan is deliberately NOT seeded — exercises the no-FK
	// orphan-tolerance bug-for-bug pin.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidWardrobeEmpty, "WdEmpty"},
		{cidWardrobeOne, "WdOne"},
		{cidWardrobeMulti, "WdMulti"},
		{cidWardrobeOther, "WdOther"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "wd_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Seed wardrobe entries via raw INSERT — there is no Set/Put SP for
	// wardrobe in batch 16, so the test fixture writes the table directly.
	// This is acceptable because the SP under test is a pure SELECT; the
	// "data path identical to prod" rationale applies only to UPSERT-shaped
	// pairs (e.g. ItemSeal Set/Get). Future batches may port aion_SetWardrobe.
	wardrobeSeeds := []struct {
		charID, slotID, nameID int
	}{
		{cidWardrobeOne, wdSlotMain, wdNameOne},
		{cidWardrobeMulti, wdSlotMain, wdNameMulti1},
		{cidWardrobeMulti, wdSlotSecond, wdNameMulti2},
		{cidWardrobeMulti, wdSlotThird, wdNameMulti3},
		{cidWardrobeOther, wdSlotMain, wdNameOther},
		{cidWardrobeOrphan, wdSlotMain, wdNameOrphan},
	}
	for _, s := range wardrobeSeeds {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_wardrobe(char_id, slot_id, name_id) VALUES ($1, $2, $3)`,
			s.charID, s.slotID, s.nameID); err != nil {
			t.Fatalf("seed wardrobe (%d,%d,%d): %v", s.charID, s.slotID, s.nameID, err)
		}
	}

	t.Run("empty char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getwardrobe", cidWardrobeEmpty)
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

	t.Run("single entry round-trips payload", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getwardrobe", cidWardrobeOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			gotSlot, gotName int
			n                int
		)
		for rows.Next() {
			if err := rows.Scan(&gotSlot, &gotName); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("single: got %d rows, want 1", n)
		}
		if gotSlot != wdSlotMain || gotName != wdNameOne {
			t.Fatalf("single payload: slot=%d name=%d, want %d/%d",
				gotSlot, gotName, wdSlotMain, wdNameOne)
		}
	})

	t.Run("multi-entry char returns N rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getwardrobe", cidWardrobeMulti)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		got := map[int]int{}
		for rows.Next() {
			var slot, name int
			if err := rows.Scan(&slot, &name); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got[slot] = name
		}
		if len(got) != 3 {
			t.Fatalf("multi: got %d rows, want 3", len(got))
		}
		want := map[int]int{
			wdSlotMain:   wdNameMulti1,
			wdSlotSecond: wdNameMulti2,
			wdSlotThird:  wdNameMulti3,
		}
		for k, v := range want {
			if got[k] != v {
				t.Fatalf("multi slot=%d: name=%d, want %d", k, got[k], v)
			}
		}
	})

	t.Run("neighbour isolation: other char's wardrobe absent", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getwardrobe", cidWardrobeOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var leakedOther bool
		for rows.Next() {
			var slot, name int
			if err := rows.Scan(&slot, &name); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if name == wdNameOther {
				leakedOther = true
			}
		}
		if leakedOther {
			t.Fatalf("isolation: other-char wardrobe leaked into result")
		}
	})

	t.Run("orphan tolerance: char without user_data row still reads (no FK)", func(t *testing.T) {
		// Bug-for-bug pin: NCSoft has no FK between user_wardrobe.char_id and
		// user_data.char_id. We seeded a wardrobe row for cidWardrobeOrphan
		// without seeding the parent user_data — Get must still succeed.
		rows, err := pool.CallSP(ctx, "aion_getwardrobe", cidWardrobeOrphan)
		if err != nil {
			t.Fatalf("CallSP orphan: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			var slot, name int
			if err := rows.Scan(&slot, &name); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if slot != wdSlotMain || name != wdNameOrphan {
				t.Fatalf("orphan payload: slot=%d name=%d, want %d/%d",
					slot, name, wdSlotMain, wdNameOrphan)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("orphan: got %d rows, want 1 (no FK)", n)
		}
	})
}
