// Package database — integration test for aion_GetEnslaveStone.
//
// Reads a single enslave-stone row by user_item.id, returning
// (status, monsterClass, lev, exp). Sister of 00215 PutEnslaveStone.
//
// Test matrix:
//   - unknown id returns 0 rows (no error)
//   - fresh stone (Put-then-Get) returns one row with all-zero defaults
//   - mutated stone (manual UPDATE) returns the new payload — verifies
//     all four columns round-trip including the wide BIGINT exp
//   - id is the only filter — no char_id parameter (bug-for-bug pin)
//   - neighbour isolation: distinct ids do not collide on PK
//
// char_id band: 9_540_001..9_540_004 (R16 batch — only used to seed
// user_data so failure-on-first-call orphan logic is testable; the SP
// itself takes only id, not char_id).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	// Enslave-stone item ids — distinct band (8_000_030_xxx) to avoid
	// collision with batches 14/15 (8000000099/8000010299/8000020999).
	itemEnslaveFresh   = int64(8000030001)
	itemEnslaveMutated = int64(8000030002)
	itemEnslaveSibling = int64(8000030003)
	itemEnslaveUnknown = int64(8000030099)
)

func getEnslaveStoneCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_enslave_stone WHERE id BETWEEN 8000030001 AND 8000030099`); err != nil {
		t.Fatalf("getEnslaveStoneCleanup user_item_enslave_stone: %v", err)
	}
}

func TestGetEnslaveStone(t *testing.T) {
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

	getEnslaveStoneCleanup(t, ctx, pool)
	t.Cleanup(func() { getEnslaveStoneCleanup(t, context.Background(), pool) })

	// Seed: itemEnslaveFresh via PutEnslaveStone (production-path).
	if err := pool.CallSPExec(ctx, "aion_putenslavestone", itemEnslaveFresh); err != nil {
		t.Fatalf("seed fresh via Put: %v", err)
	}
	// itemEnslaveMutated — Put then mutate via raw UPDATE (game logic
	// would normally call a separate Set SP; ours hasn't been ported yet
	// so we exercise the wide column shape here).
	if err := pool.CallSPExec(ctx, "aion_putenslavestone", itemEnslaveMutated); err != nil {
		t.Fatalf("seed mutated via Put: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`UPDATE user_item_enslave_stone
		    SET status=$1, "monsterClass"=$2, lev=$3, exp=$4
		  WHERE id=$5`,
		2, 215001, 50, int64(9876543210), itemEnslaveMutated); err != nil {
		t.Fatalf("mutate row: %v", err)
	}
	// Sibling (left at fresh defaults) — used to prove distinct-id isolation.
	if err := pool.CallSPExec(ctx, "aion_putenslavestone", itemEnslaveSibling); err != nil {
		t.Fatalf("seed sibling via Put: %v", err)
	}

	t.Run("unknown id returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getenslavestone", itemEnslaveUnknown)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var cnt int
		for rows.Next() {
			cnt++
		}
		if cnt != 0 {
			t.Fatalf("unknown id: got %d rows, want 0", cnt)
		}
	})

	t.Run("fresh stone returns all-zero defaults", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getenslavestone", itemEnslaveFresh)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			status, monsterClass, lev int
			exp                       int64
		)
		var n int
		for rows.Next() {
			if err := rows.Scan(&status, &monsterClass, &lev, &exp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("fresh: got %d rows, want 1", n)
		}
		// PutEnslaveStone hard-codes (0,0,0,0) — bug-for-bug pin verified.
		if status != 0 || monsterClass != 0 || lev != 0 || exp != 0 {
			t.Fatalf("fresh defaults: got (%d,%d,%d,%d), want (0,0,0,0)",
				status, monsterClass, lev, exp)
		}
	})

	t.Run("mutated stone round-trips full payload", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getenslavestone", itemEnslaveMutated)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			status, monsterClass, lev int
			exp                       int64
		)
		var n int
		for rows.Next() {
			if err := rows.Scan(&status, &monsterClass, &lev, &exp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("mutated: got %d rows, want 1", n)
		}
		// Spot-check the wide BIGINT exp does not silently truncate — pinning
		// the schema-delta decision (NCSoft INT widened to PG BIGINT).
		if status != 2 || monsterClass != 215001 || lev != 50 || exp != 9876543210 {
			t.Fatalf("mutated payload: got (%d,%d,%d,%d), want (2,215001,50,9876543210)",
				status, monsterClass, lev, exp)
		}
	})

	t.Run("neighbour isolation: distinct ids do not collide", func(t *testing.T) {
		// Sibling row was seeded via Put (defaults). Mutating Mutated must not
		// have leaked into Sibling — verify Sibling still reads (0,0,0,0).
		rows, err := pool.CallSP(ctx, "aion_getenslavestone", itemEnslaveSibling)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			status, monsterClass, lev int
			exp                       int64
		)
		var n int
		for rows.Next() {
			if err := rows.Scan(&status, &monsterClass, &lev, &exp); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("sibling: got %d rows, want 1", n)
		}
		if status != 0 || monsterClass != 0 || lev != 0 || exp != 0 {
			t.Fatalf("sibling collateral damage: got (%d,%d,%d,%d)",
				status, monsterClass, lev, exp)
		}
	})
}
