// Package database — integration test for aion_PutGatherCoolTime (upsert).
//
// Atomic INSERT-or-UPDATE on user_gather_cooltime keyed by (char_id,
// cooltime_id). Pairs with aion_GetGatherCoolTimeList (00172) reader.
//
// Test matrix:
//   - first call inserts, returns 1 affected row, expire persists exactly
//   - second call on same (char_id, cooltime_id) updates expire in place
//     (still 1 row, no duplicate)
//   - second cooltime_id on same char inserts as a new row
//   - bigint precision: millisecond-scale timestamps survive round-trip
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPgctA = 9001947 // upsert target
	cidPgctB = 9001948 // separate char (row isolation)
)

func putGatherCoolTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_gather_cooltime WHERE char_id BETWEEN 9001947 AND 9001949`); err != nil {
		t.Fatalf("putGatherCoolTimeCleanup user_gather_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001947 AND 9001949`); err != nil {
		t.Fatalf("putGatherCoolTimeCleanup user_data: %v", err)
	}
}

func TestPutGatherCoolTime(t *testing.T) {
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

	putGatherCoolTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { putGatherCoolTimeCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidPgctA, "PgctA"},
		{cidPgctB, "PgctB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "pg_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("first put inserts new cooldown row", func(t *testing.T) {
		expire := int64(1850000000000) // ms
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putgathercooltime",
			cidPgctA, int32(60001), expire).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first put: got %d, want 1", affected)
		}

		var gotExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_cooltime FROM user_gather_cooltime
			  WHERE char_id = $1 AND cooltime_id = $2`,
			cidPgctA, 60001).Scan(&gotExpire); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if gotExpire != expire {
			t.Fatalf("expire mismatch: got %d, want %d", gotExpire, expire)
		}
	})

	t.Run("second put on same key updates expire (no duplicate)", func(t *testing.T) {
		newExpire := int64(1950000000000)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putgathercooltime",
			cidPgctA, int32(60001), newExpire).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("update put: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_gather_cooltime
			  WHERE char_id = $1 AND cooltime_id = $2`,
			cidPgctA, 60001).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after update: got %d, want 1 (no duplicate)", rowCnt)
		}

		var gotExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_cooltime FROM user_gather_cooltime
			  WHERE char_id = $1 AND cooltime_id = $2`,
			cidPgctA, 60001).Scan(&gotExpire); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if gotExpire != newExpire {
			t.Fatalf("updated expire mismatch: got %d, want %d", gotExpire, newExpire)
		}
	})

	t.Run("different cooltime_id on same char inserts new row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putgathercooltime",
			cidPgctA, int32(60002), int64(1700000000000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("new cooltime_id: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_gather_cooltime WHERE char_id = $1`,
			cidPgctA).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 2 {
			t.Fatalf("rows for char: got %d, want 2 (60001 + 60002)", rowCnt)
		}
	})

	t.Run("isolated char + bigint extreme survives round-trip", func(t *testing.T) {
		// max signed 63-bit value − 1 — guards against any 32-bit truncation
		// path in the driver/SP boundary.
		extreme := int64(9223372036854775806)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putgathercooltime",
			cidPgctB, int32(70001), extreme).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow extreme: %v", err)
		}
		if affected != 1 {
			t.Fatalf("extreme put: got %d, want 1", affected)
		}

		var gotExpire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_cooltime FROM user_gather_cooltime
			  WHERE char_id = $1 AND cooltime_id = $2`,
			cidPgctB, 70001).Scan(&gotExpire); err != nil {
			t.Fatalf("verify extreme: %v", err)
		}
		if gotExpire != extreme {
			t.Fatalf("bigint round-trip lost precision: got %d, want %d", gotExpire, extreme)
		}
	})
}
