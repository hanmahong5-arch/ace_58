// Package database — integration test for aion_PutCombineCoolTime (per-row
// upsert; sister write of 00167 GetCombineCoolTimeList).
//
// Composite-PK (char_id, cooltime_id) — distinct combine classes coexist
// per char. ON CONFLICT DO UPDATE rewrites expire_cooltime in place.
//
// Test matrix:
//   - first call inserts a row, expire_cooltime round-trips
//   - second call with same (char, cooltime_id) UPDATEs (no second row)
//   - distinct cooltime_ids on same char coexist
//   - distinct chars coexist
//   - negative expire_cooltime accepted (NCSoft sentinel for "expired")
//
// char_id band: 9_600_020..9_600_039 (batch 22 — combine_cooltime sub-band).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPCombCT_A    = 9600020
	cidPCombCT_B    = 9600021
	cidPCombCT_Updt = 9600022
	cidPCombCT_Neg  = 9600023 // negative expire (NCSoft sentinel)
)

func putCombineCoolTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_combine_cooltime WHERE char_id BETWEEN 9600020 AND 9600039`); err != nil {
		t.Fatalf("putCombineCoolTimeCleanup: %v", err)
	}
}

func TestPutCombineCoolTime(t *testing.T) {
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

	putCombineCoolTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { putCombineCoolTimeCleanup(t, context.Background(), pool) })

	t.Run("first call inserts, payload round-trips", func(t *testing.T) {
		if _, err := pool.CallSP(ctx, "aion_putcombinecooltime",
			cidPCombCT_A, int(40101), int64(1730000000000)); err != nil {
			t.Fatalf("first insert: %v", err)
		}
		var expire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_cooltime FROM user_combine_cooltime
			  WHERE char_id=$1 AND cooltime_id=$2`,
			cidPCombCT_A, 40101).Scan(&expire); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if expire != 1730000000000 {
			t.Fatalf("expire round-trip: got %d, want 1730000000000", expire)
		}
	})

	t.Run("second call with same composite PK UPDATEs in place", func(t *testing.T) {
		// First insert.
		if _, err := pool.CallSP(ctx, "aion_putcombinecooltime",
			cidPCombCT_Updt, int(40201), int64(1000)); err != nil {
			t.Fatalf("first: %v", err)
		}
		// Second call — UPDATE, not duplicate.
		if _, err := pool.CallSP(ctx, "aion_putcombinecooltime",
			cidPCombCT_Updt, int(40201), int64(2000)); err != nil {
			t.Fatalf("upsert: %v", err)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_combine_cooltime WHERE char_id=$1`,
			cidPCombCT_Updt).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("row count: got %d, want 1", n)
		}

		var expire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_cooltime FROM user_combine_cooltime
			  WHERE char_id=$1 AND cooltime_id=$2`,
			cidPCombCT_Updt, 40201).Scan(&expire); err != nil {
			t.Fatalf("verify upsert: %v", err)
		}
		if expire != 2000 {
			t.Fatalf("upsert expire: got %d, want 2000", expire)
		}
	})

	t.Run("distinct cooltime_ids on same char coexist", func(t *testing.T) {
		// 3 distinct combine-class throttles for cidPCombCT_A (which already
		// owns 40101 from the first sub-test).
		for _, cid := range []int{40102, 40103, 40104} {
			if _, err := pool.CallSP(ctx, "aion_putcombinecooltime",
				cidPCombCT_A, cid, int64(1700000000000)); err != nil {
				t.Fatalf("insert cid=%d: %v", cid, err)
			}
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_combine_cooltime WHERE char_id=$1`,
			cidPCombCT_A).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 4 {
			t.Fatalf("rows for char A: got %d, want 4", n)
		}
	})

	t.Run("distinct chars coexist on same cooltime_id", func(t *testing.T) {
		if _, err := pool.CallSP(ctx, "aion_putcombinecooltime",
			cidPCombCT_B, int(40101), int64(9999)); err != nil {
			t.Fatalf("char B: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_combine_cooltime
			  WHERE char_id IN ($1, $2) AND cooltime_id=$3`,
			cidPCombCT_A, cidPCombCT_B, 40101).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 2 {
			t.Fatalf("two chars same cid: got %d, want 2", n)
		}
	})

	t.Run("negative expire_cooltime accepted (NCSoft sentinel)", func(t *testing.T) {
		if _, err := pool.CallSP(ctx, "aion_putcombinecooltime",
			cidPCombCT_Neg, int(40301), int64(-1)); err != nil {
			t.Fatalf("negative expire: %v", err)
		}
		var expire int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_cooltime FROM user_combine_cooltime
			  WHERE char_id=$1 AND cooltime_id=$2`,
			cidPCombCT_Neg, 40301).Scan(&expire); err != nil {
			t.Fatalf("verify negative: %v", err)
		}
		if expire != -1 {
			t.Fatalf("negative round-trip: got %d, want -1", expire)
		}
	})
}
