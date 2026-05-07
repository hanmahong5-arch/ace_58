// Package database — integration test for aion_PutEmotion.
//
// UPSERT on (char_id, emotion_type). NCSoft semantics: at most one row per
// (char_id, emotion_type); a re-grant updates expire_date in place.
//
// Test matrix:
//   - happy path: first put on a new (char_id, emotion_type) inserts 1 row
//   - rebind: second put with same (char_id, emotion_type) updates expire_date
//   - distinct types coexist: same char with different emotion_type → 2 rows
//   - neighbour isolation: putting for char A doesn't perturb char B
//   - missing char: PutEmotion succeeds even when user_data row is absent
//     (bug-for-bug — NCSoft has no FK guard; emotion table is freestanding)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidEmotionA       = 9450001
	cidEmotionB       = 9450002
	cidEmotionMissing = 9450099 // no user_data seed; PutEmotion must still work
)

func putEmotionCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_emotion WHERE char_id BETWEEN 9450001 AND 9450099`); err != nil {
		t.Fatalf("putEmotionCleanup user_emotion: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9450001 AND 9450099`); err != nil {
		t.Fatalf("putEmotionCleanup user_data: %v", err)
	}
}

func TestPutEmotion(t *testing.T) {
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

	putEmotionCleanup(t, ctx, pool)
	t.Cleanup(func() { putEmotionCleanup(t, context.Background(), pool) })

	// Seed two char rows so PutEmotion has a parent in the typical flow.
	// The missing-char (cidEmotionMissing) is intentionally NOT seeded.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidEmotionA, "EmoCharA"},
		{cidEmotionB, "EmoCharB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "emo_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: first put inserts 1 row, expire_date matches", func(t *testing.T) {
		var (
			emotionType int16 = 5
			expireDate  int64 = 1_799_000_000 // safely past 2024 epoch
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putemotion",
			cidEmotionA, emotionType, expireDate).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var gotExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_date FROM user_emotion
			  WHERE char_id = $1 AND emotion_type = $2`,
			cidEmotionA, emotionType).Scan(&gotExpire); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if gotExpire != expireDate {
			t.Fatalf("expire_date: got %d, want %d", gotExpire, expireDate)
		}
	})

	t.Run("rebind: same (char_id, type) updates expire_date in place", func(t *testing.T) {
		var (
			emotionType   int16 = 5
			expireDateNew int64 = 1_999_999_999
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putemotion",
			cidEmotionA, emotionType, expireDateNew).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow rebind: %v", err)
		}
		if affected != 1 {
			t.Fatalf("rebind affected: got %d, want 1", affected)
		}

		// Exactly 1 row must exist for this (char_id, emotion_type).
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_emotion
			  WHERE char_id = $1 AND emotion_type = $2`,
			cidEmotionA, emotionType).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rebind cnt: got %d, want 1", cnt)
		}

		var gotExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_date FROM user_emotion
			  WHERE char_id = $1 AND emotion_type = $2`,
			cidEmotionA, emotionType).Scan(&gotExpire); err != nil {
			t.Fatalf("verify rebind: %v", err)
		}
		if gotExpire != expireDateNew {
			t.Fatalf("rebind expire_date: got %d, want %d", gotExpire, expireDateNew)
		}
	})

	t.Run("distinct types coexist on same char", func(t *testing.T) {
		// type=5 already exists from happy/rebind. Add type=7 — must not
		// collide with the (char,5) row.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putemotion",
			cidEmotionA, int16(7), int64(1_700_000_007)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow type7: %v", err)
		}
		if affected != 1 {
			t.Fatalf("type7: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_emotion WHERE char_id = $1`,
			cidEmotionA).Scan(&cnt); err != nil {
			t.Fatalf("count by char: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("two types on same char: got %d rows, want 2", cnt)
		}
	})

	t.Run("neighbour isolation: A's put doesn't perturb B", func(t *testing.T) {
		// Put on B with a clearly distinct expire_date.
		if err := pool.CallSPExec(ctx, "aion_putemotion",
			cidEmotionB, int16(5), int64(1_111_111_111)); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}

		// A's (char,5) row must still hold the rebind value, not B's.
		var aExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_date FROM user_emotion
			  WHERE char_id = $1 AND emotion_type = 5`,
			cidEmotionA).Scan(&aExpire); err != nil {
			t.Fatalf("verify A intact: %v", err)
		}
		if aExpire != 1_999_999_999 {
			t.Fatalf("A leaked from B: got %d, want 1999999999", aExpire)
		}

		// B's (char,5) row must hold its own value.
		var bExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_date FROM user_emotion
			  WHERE char_id = $1 AND emotion_type = 5`,
			cidEmotionB).Scan(&bExpire); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if bExpire != 1_111_111_111 {
			t.Fatalf("B value: got %d, want 1111111111", bExpire)
		}
	})

	t.Run("missing user_data: PutEmotion still succeeds (no FK)", func(t *testing.T) {
		// Bug-for-bug: NCSoft never enforces a parent existence guard. The
		// emotion table is freestanding so an orphan put is silently accepted.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putemotion",
			cidEmotionMissing, int16(3), int64(1_500_000_000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 1 {
			t.Fatalf("missing affected: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_emotion WHERE char_id = $1`,
			cidEmotionMissing).Scan(&cnt); err != nil {
			t.Fatalf("count missing: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("missing cnt: got %d, want 1", cnt)
		}
	})
}
