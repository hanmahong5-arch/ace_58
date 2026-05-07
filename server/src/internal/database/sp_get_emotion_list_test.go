// Package database — integration test for aion_GetEmotionList.
//
// Returns (emotion_type, expire_date) for a char's purchased emote slots.
// Char-id range 9001900-9001999 reserved for this suite.
//
// Test matrix:
//   - char with multiple emotes: rows ordered by emotion_type, both columns project
//   - char with no emotes: 0 rows
//   - distinct char's emotes are isolated (no row leak across char_id boundary)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidEmoOwnerA = 9001900 // owns 3 emotes (one expired, kept anyway — no filter in source)
	cidEmoOwnerB = 9001901 // owns 1 emote
	cidEmoEmpty  = 9001902 // owns 0 emotes
)

func getEmotionListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_emotion WHERE char_id BETWEEN 9001900 AND 9001999`); err != nil {
		t.Fatalf("getEmotionListCleanup user_emotion: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001900 AND 9001999`); err != nil {
		t.Fatalf("getEmotionListCleanup user_data: %v", err)
	}
}

func TestGetEmotionList(t *testing.T) {
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

	getEmotionListCleanup(t, ctx, pool)
	t.Cleanup(func() { getEmotionListCleanup(t, context.Background(), pool) })

	// Seed user_data so cm_* layer FK invariants hold.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidEmoOwnerA, "EmoOwnerA"},
		{cidEmoOwnerB, "EmoOwnerB"},
		{cidEmoEmpty, "EmoEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "em_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// OwnerA: three emotes with distinct types & expire_dates (one is "expired"
	// at expire_date=0 — original SP has no filter on this so it must show up).
	type seedRow struct {
		charID, emotionID int
		etype             int16
		expireDate        int64
	}
	rowsToSeed := []seedRow{
		{cidEmoOwnerA, 5001, 1, 1700001000},
		{cidEmoOwnerA, 5002, 0, 1700002000},
		{cidEmoOwnerA, 5003, 2, 0}, // expired tombstone — still returned
		{cidEmoOwnerB, 5099, 1, 1800000000},
	}
	for _, r := range rowsToSeed {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_emotion(char_id, emotion_id, emotion_type, expire_date)
			 VALUES ($1, $2, $3, $4)`,
			r.charID, r.emotionID, r.etype, r.expireDate); err != nil {
			t.Fatalf("seed emotion (%d,%d): %v", r.charID, r.emotionID, err)
		}
	}

	t.Run("owner with multiple emotes returns all rows ordered by emotion_type", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getemotionlist", cidEmoOwnerA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		var (
			gotTypes []int16
			gotDates []int64
		)
		for rs.Next() {
			var etype int16
			var date int64
			if err := rs.Scan(&etype, &date); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			gotTypes = append(gotTypes, etype)
			gotDates = append(gotDates, date)
		}
		// Expect 3 rows; ORDER BY emotion_type ASC → 0,1,2
		if len(gotTypes) != 3 {
			t.Fatalf("row count: got %d, want 3", len(gotTypes))
		}
		wantTypes := []int16{0, 1, 2}
		for i, want := range wantTypes {
			if gotTypes[i] != want {
				t.Fatalf("emotion_type[%d]: got %d, want %d (rows must be ordered)",
					i, gotTypes[i], want)
			}
		}
		// Spot-check expire_date round-trip — type=0 had date=1700002000.
		if gotDates[0] != 1700002000 {
			t.Fatalf("expire_date for type=0: got %d, want 1700002000", gotDates[0])
		}
		// Tombstone (expire_date=0) on type=2 must surface (no filter).
		if gotDates[2] != 0 {
			t.Fatalf("expire_date for type=2 (tombstone): got %d, want 0 (must NOT be filtered)",
				gotDates[2])
		}
	})

	t.Run("owner with no emotes returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getemotionlist", cidEmoEmpty)
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

	t.Run("char_id boundary: ownerB rows do not leak into ownerA", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getemotionlist", cidEmoOwnerB)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var n int
		var lastDate int64
		for rs.Next() {
			var etype int16
			if err := rs.Scan(&etype, &lastDate); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("ownerB row count: got %d, want 1", n)
		}
		if lastDate != 1800000000 {
			t.Fatalf("ownerB expire_date: got %d, want 1800000000 (proves no leak)", lastDate)
		}
	})
}
