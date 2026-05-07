// Package database — integration test for aion_block_offline_buddy.
//
// Three return codes (0 happy / 0 idempotent / 3 cap / 4 active-friend rail).
//
// Test matrix:
//   - happy path (no friend, not blocked) → 0 + row inserted with empty comment
//   - already blocked → 0 (idempotent), no second row
//   - active friendship rail → 4, no row inserted
//   - block-list at 200 cap → 3, no row inserted
//   - soft-deleted friend (delete_flag=1) does NOT trigger the rail → 0
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidBlkOffOwner    = 9002600
	cidBlkOffTarget   = 9002601 // happy
	cidBlkOffAlready  = 9002602 // already in user_block
	cidBlkOffFriend   = 9002603 // active friend → triggers code 4
	cidBlkOffSoftDel  = 9002604 // soft-deleted friend → must NOT trigger 4
	cidBlkOffCapOwner = 9002605 // saturated to 200 user_block rows
	cidBlkOffSpare    = 9002606
)

func blockOfflineBuddyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, q := range []string{
		`DELETE FROM user_block      WHERE char_id BETWEEN 9002600 AND 9002899 OR block_id BETWEEN 9002600 AND 9002899`,
		`DELETE FROM user_buddy_list WHERE char_id BETWEEN 9002600 AND 9002899 OR buddy_id BETWEEN 9002600 AND 9002899`,
		`DELETE FROM user_data       WHERE char_id BETWEEN 9002600 AND 9002899`,
	} {
		if _, err := p.Inner().Exec(ctx, q); err != nil {
			t.Fatalf("blockOfflineBuddyCleanup %q: %v", q, err)
		}
	}
}

func TestBlockOfflineBuddy(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	blockOfflineBuddyCleanup(t, ctx, pool)
	t.Cleanup(func() { blockOfflineBuddyCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidBlkOffOwner, "BlkOwner"},
		{cidBlkOffTarget, "BlkTgt"},
		{cidBlkOffAlready, "BlkAlready"},
		{cidBlkOffFriend, "BlkFriend"},
		{cidBlkOffSoftDel, "BlkSoftDel"},
		{cidBlkOffCapOwner, "BlkCapOwner"},
		{cidBlkOffSpare, "BlkSpare"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "bk_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Pre-seed an active friendship and a soft-deleted one.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES
		 ($1, $2, 0), ($1, $3, 1)`,
		cidBlkOffOwner, cidBlkOffFriend, cidBlkOffSoftDel); err != nil {
		t.Fatalf("seed buddy: %v", err)
	}
	// Pre-seed an existing block row for idempotency test.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_block(char_id, block_id, comment) VALUES ($1, $2, 'old')`,
		cidBlkOffOwner, cidBlkOffAlready); err != nil {
		t.Fatalf("seed block: %v", err)
	}

	t.Run("happy path returns 0 and inserts empty-comment row", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_block_offline_buddy",
			cidBlkOffOwner, cidBlkOffTarget).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 0 {
			t.Fatalf("happy: got %d, want 0", rc)
		}
		var cmt string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidBlkOffOwner, cidBlkOffTarget).Scan(&cmt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cmt != "" {
			t.Fatalf("comment=%q, want empty", cmt)
		}
	})

	t.Run("already blocked returns 0 idempotent and preserves prior comment", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_block_offline_buddy",
			cidBlkOffOwner, cidBlkOffAlready).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 0 {
			t.Fatalf("idempotent: got %d, want 0", rc)
		}
		// Original comment "old" must be preserved (we did not overwrite).
		var cmt string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidBlkOffOwner, cidBlkOffAlready).Scan(&cmt); err != nil {
			t.Fatalf("verify preserve: %v", err)
		}
		if cmt != "old" {
			t.Fatalf("idempotent overwrote: %q, want %q", cmt, "old")
		}
	})

	t.Run("active friendship triggers code 4", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_block_offline_buddy",
			cidBlkOffOwner, cidBlkOffFriend).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 4 {
			t.Fatalf("active-friend: got %d, want 4", rc)
		}
		// No row in user_block for this pair.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidBlkOffOwner, cidBlkOffFriend).Scan(&cnt); err != nil {
			t.Fatalf("verify no insert: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("rail leaked: cnt=%d, want 0", cnt)
		}
	})

	t.Run("soft-deleted friend does not trigger rail", func(t *testing.T) {
		// Soft-deleted (delete_flag=1) friendship is semantically gone, so
		// blocking should succeed.
		var rc int
		if err := pool.CallSPRow(ctx, "aion_block_offline_buddy",
			cidBlkOffOwner, cidBlkOffSoftDel).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 0 {
			t.Fatalf("soft-del friend: got %d, want 0", rc)
		}
	})

	t.Run("block-list at 200 cap returns 3", func(t *testing.T) {
		// Saturate cidBlkOffCapOwner with 200 user_block rows. Use peer ids
		// 9002700..9002899 so they don't collide with primary actors.
		for i := 0; i < 200; i++ {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO user_block(char_id, block_id, comment) VALUES ($1, $2, '')
				 ON CONFLICT DO NOTHING`,
				cidBlkOffCapOwner, 9002700+i); err != nil {
				t.Fatalf("saturate: %v", err)
			}
		}

		var rc int
		if err := pool.CallSPRow(ctx, "aion_block_offline_buddy",
			cidBlkOffCapOwner, cidBlkOffSpare).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 3 {
			t.Fatalf("cap: got %d, want 3", rc)
		}
		// Verify nothing was inserted past the cap.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id = $1`,
			cidBlkOffCapOwner).Scan(&cnt); err != nil {
			t.Fatalf("verify cap: %v", err)
		}
		if cnt != 200 {
			t.Fatalf("cap row count: got %d, want 200", cnt)
		}
	})
}
