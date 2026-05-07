// Package database — integration test for aion_PutEnslaveStone.
//
// INSERT a fresh enslave-stone row keyed on user_item.id. All four mutable
// columns are HARD-CODED to 0 by the SP (NCSoft contract, pinned). Sister
// of 00214 GetEnslaveStone.
//
// Test matrix:
//   - first call inserts 1 row with (0,0,0,0) defaults
//   - duplicate id call raises a PG unique-violation error (bug-for-bug pin
//     — NCSoft did not gate on EXISTS, callers must check via Get first)
//   - distinct ids coexist (no PK collision across calls)
//
// item id band: 8_000_040_xxx (R16 batch — distinct from
// GetEnslaveStone's 8_000_030_xxx so the two suites can run in parallel).
package database

import (
	"context"
	"strings"
	"testing"
	"time"
)

const (
	itemPutEnslaveA       = int64(8000040001)
	itemPutEnslaveB       = int64(8000040002)
	itemPutEnslaveDupTest = int64(8000040003)
)

func putEnslaveStoneCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_enslave_stone WHERE id BETWEEN 8000040001 AND 8000040099`); err != nil {
		t.Fatalf("putEnslaveStoneCleanup user_item_enslave_stone: %v", err)
	}
}

func TestPutEnslaveStone(t *testing.T) {
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

	putEnslaveStoneCleanup(t, ctx, pool)
	t.Cleanup(func() { putEnslaveStoneCleanup(t, context.Background(), pool) })

	t.Run("first call inserts row with all-zero defaults", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_putenslavestone", itemPutEnslaveA); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}

		var (
			status, monsterClass, lev int
			exp                       int64
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT status, "monsterClass", lev, exp
			   FROM user_item_enslave_stone WHERE id=$1`, itemPutEnslaveA).
			Scan(&status, &monsterClass, &lev, &exp); err != nil {
			t.Fatalf("verify: %v", err)
		}
		// NCSoft hard-codes (0,0,0,0) on insert — pinned bug-for-bug.
		if status != 0 || monsterClass != 0 || lev != 0 || exp != 0 {
			t.Fatalf("fresh defaults: got (%d,%d,%d,%d), want (0,0,0,0)",
				status, monsterClass, lev, exp)
		}
	})

	t.Run("distinct ids coexist", func(t *testing.T) {
		// Putting B does not collide with A.
		if err := pool.CallSPExec(ctx, "aion_putenslavestone", itemPutEnslaveB); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_enslave_stone
			  WHERE id IN ($1, $2)`, itemPutEnslaveA, itemPutEnslaveB).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("two ids: got %d rows, want 2", cnt)
		}
	})

	t.Run("duplicate id raises unique-violation (bug-for-bug pin)", func(t *testing.T) {
		// Bug-for-bug pin: NCSoft has no ON CONFLICT / no MERGE — a duplicate
		// PK raises 2627. PG raises SQLSTATE 23505 (unique_violation). The
		// caller MUST detect "already exists" via Get before calling Put.
		// We seed once successfully …
		if err := pool.CallSPExec(ctx, "aion_putenslavestone", itemPutEnslaveDupTest); err != nil {
			t.Fatalf("first Put: %v", err)
		}
		// … then the second call must error.
		err := pool.CallSPExec(ctx, "aion_putenslavestone", itemPutEnslaveDupTest)
		if err == nil {
			t.Fatalf("duplicate Put: expected error, got nil — ON CONFLICT slipped in?")
		}
		if !strings.Contains(err.Error(), "23505") &&
			!strings.Contains(strings.ToLower(err.Error()), "duplicate") &&
			!strings.Contains(strings.ToLower(err.Error()), "unique") {
			t.Fatalf("duplicate Put: expected unique-violation, got: %v", err)
		}

		// Row count is still 1 — the failed insert did not create a phantom.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_enslave_stone WHERE id=$1`,
			itemPutEnslaveDupTest).Scan(&cnt); err != nil {
			t.Fatalf("post-fail count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("after duplicate failure: got %d rows, want 1", cnt)
		}
	})
}
