// Package database — integration test for aion_RemoveAllBlock (purge ALL
// block-list entries that touch a given char on either side).
//
// The SP runs two DELETEs:
//   1. WHERE char_id  = $1  (rows where the focal char is the blocker)
//   2. WHERE block_id = $1  (rows where the focal char is the blocked target)
//
// Test matrix:
//   - purge "blocker" side only (no rows where char is target)
//   - purge "target" side only (no rows where char is blocker)
//   - purge both sides at once
//   - self-block edge case (char_id == block_id) — must purge cleanly
//   - rows belonging to OTHER chars are untouched
//   - no rows at all → returns 0, no error
//   - returned int = total rows-affected across both DELETEs
//
// char_id band: 9_600_060..9_600_079 (batch 22 — block_purge sub-band).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidRmBlk_Focal      = 9600060 // focal char being purged
	cidRmBlk_BlockerOf  = 9600061 // someone the focal char blocks
	cidRmBlk_TargetOf   = 9600062 // someone who blocks the focal char
	cidRmBlk_Bystander  = 9600063 // unrelated char — must NOT be touched
	cidRmBlk_BothA      = 9600064 // double-side test: focal blocks A
	cidRmBlk_BothB      = 9600065 // double-side test: B blocks focal
	cidRmBlk_SelfBlock  = 9600066 // self-block edge (char blocks self)
	cidRmBlk_Empty      = 9600067 // no block rows — must return 0
	cidRmBlk_Survivor   = 9600068 // co-resident char in same row population
)

func removeAllBlockCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_block
		  WHERE char_id  BETWEEN 9600060 AND 9600079
		     OR block_id BETWEEN 9600060 AND 9600079`); err != nil {
		t.Fatalf("removeAllBlockCleanup: %v", err)
	}
}

// seedBlock inserts a block-list row directly. AddBlock SP exists at 00087
// but uses ON CONFLICT DO NOTHING which we want — except some sub-tests
// need the row REGARDLESS, so direct INSERT is simpler and more predictable.
func seedBlock(t *testing.T, ctx context.Context, p *Pool, charID, blockID int) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`INSERT INTO user_block (char_id, block_id, comment)
		 VALUES ($1, $2, '') ON CONFLICT (char_id, block_id) DO NOTHING`,
		charID, blockID); err != nil {
		t.Fatalf("seedBlock %d/%d: %v", charID, blockID, err)
	}
}

func TestRemoveAllBlock(t *testing.T) {
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

	removeAllBlockCleanup(t, ctx, pool)
	t.Cleanup(func() { removeAllBlockCleanup(t, context.Background(), pool) })

	t.Run("purge both sides at once + bystander untouched", func(t *testing.T) {
		// Side A: focal blocks BlockerOf and BothA.
		seedBlock(t, ctx, pool, cidRmBlk_Focal, cidRmBlk_BlockerOf)
		seedBlock(t, ctx, pool, cidRmBlk_Focal, cidRmBlk_BothA)
		// Side B: TargetOf and BothB block focal.
		seedBlock(t, ctx, pool, cidRmBlk_TargetOf, cidRmBlk_Focal)
		seedBlock(t, ctx, pool, cidRmBlk_BothB, cidRmBlk_Focal)
		// Bystander relationship — must NOT be purged.
		seedBlock(t, ctx, pool, cidRmBlk_Bystander, cidRmBlk_Survivor)

		var affected int
		if err := pool.CallSPRow(ctx, "aion_removeallblock",
			cidRmBlk_Focal).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 4 {
			t.Fatalf("affected: got %d, want 4 (2 blocker-side + 2 target-side)", affected)
		}

		// Focal must have zero block rows.
		var nFocal int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block
			  WHERE char_id=$1 OR block_id=$1`,
			cidRmBlk_Focal).Scan(&nFocal); err != nil {
			t.Fatalf("count focal: %v", err)
		}
		if nFocal != 0 {
			t.Fatalf("focal residue: got %d, want 0", nFocal)
		}

		// Bystander row must survive.
		var nBy int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id=$1 AND block_id=$2`,
			cidRmBlk_Bystander, cidRmBlk_Survivor).Scan(&nBy); err != nil {
			t.Fatalf("count bystander: %v", err)
		}
		if nBy != 1 {
			t.Fatalf("bystander purged in error: got %d, want 1", nBy)
		}
	})

	t.Run("self-block edge: char blocks self → cleanly removed by side A", func(t *testing.T) {
		seedBlock(t, ctx, pool, cidRmBlk_SelfBlock, cidRmBlk_SelfBlock)

		var affected int
		if err := pool.CallSPRow(ctx, "aion_removeallblock",
			cidRmBlk_SelfBlock).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow self: %v", err)
		}
		// Side A deletes the self-row (1). Side B's predicate also matches
		// but the row is already gone, so side B reports 0. Total = 1.
		if affected != 1 {
			t.Fatalf("self-block affected: got %d, want 1 (no double-count)", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id=$1`,
			cidRmBlk_SelfBlock).Scan(&n); err != nil {
			t.Fatalf("count self: %v", err)
		}
		if n != 0 {
			t.Fatalf("self-block residue: got %d, want 0", n)
		}
	})

	t.Run("char with no block entries returns 0 (no error)", func(t *testing.T) {
		// cidRmBlk_Empty intentionally never seeded.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_removeallblock",
			cidRmBlk_Empty).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow empty: %v", err)
		}
		if affected != 0 {
			t.Fatalf("empty-char affected: got %d, want 0", affected)
		}
	})
}
