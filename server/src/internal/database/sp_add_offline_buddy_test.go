// Package database — integration test for aion_add_offline_buddy.
//
// Pending invite queue: SP exercises four short-circuit return codes plus
// the success path. Test matrix mirrors the NCSoft return-code catalogue
// (11/12/13/14/19) so a regression in any branch surfaces as a distinct
// assertion failure rather than a silent count drift.
//
// Test matrix:
//   - happy path → return 11 + row inserted
//   - already-pending inbound (charid, inviter) → return 12, no second row
//   - already-pending outbound (inviter, charid) → return 19, no row
//   - invitee at cap (100 buddy_list rows) → return 14, no row
//   - inviter at cap → return 13, no row
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAddOffBA       = 9002100 // invitee
	cidAddOffBB       = 9002101 // inviter
	cidAddOffBCapInv  = 9002102 // invitee saturated to 100
	cidAddOffBCapInvr = 9002103 // inviter saturated to 100
	cidAddOffBExtra   = 9002104 // dummy buddy used to fill the cap
	// 9002200..9002299 = 100 dummy peer ids used as buddy_id rows for cap tests
)

func addOfflineBuddyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, q := range []string{
		`DELETE FROM user_buddy_offline WHERE user_id BETWEEN 9002100 AND 9002299 OR inviter_id BETWEEN 9002100 AND 9002299`,
		`DELETE FROM user_buddy_inter   WHERE char_id BETWEEN 9002100 AND 9002299 OR buddy_id BETWEEN 9002100 AND 9002299`,
		`DELETE FROM user_buddy_list    WHERE char_id BETWEEN 9002100 AND 9002299 OR buddy_id BETWEEN 9002100 AND 9002299`,
		`DELETE FROM user_data          WHERE char_id BETWEEN 9002100 AND 9002299`,
	} {
		if _, err := p.Inner().Exec(ctx, q); err != nil {
			t.Fatalf("addOfflineBuddyCleanup %q: %v", q, err)
		}
	}
}

func TestAddOfflineBuddy(t *testing.T) {
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

	addOfflineBuddyCleanup(t, ctx, pool)
	t.Cleanup(func() { addOfflineBuddyCleanup(t, context.Background(), pool) })

	// Seed primary actors.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidAddOffBA, "AddOffA"},
		{cidAddOffBB, "AddOffB"},
		{cidAddOffBCapInv, "AddOffCapInv"},
		{cidAddOffBCapInvr, "AddOffCapInvr"},
		{cidAddOffBExtra, "AddOffExtra"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "ao_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("happy path returns 11 and inserts row", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_add_offline_buddy",
			cidAddOffBA, cidAddOffBB, "InviterName", "play with me!",
			47, 3, 0).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 11 {
			t.Fatalf("happy: got %d, want 11", rc)
		}
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_offline WHERE user_id = $1 AND inviter_id = $2`,
			cidAddOffBA, cidAddOffBB).Scan(&cnt); err != nil {
			t.Fatalf("verify row: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("row count: got %d, want 1", cnt)
		}
	})

	t.Run("duplicate inbound returns 12 and does not insert", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_add_offline_buddy",
			cidAddOffBA, cidAddOffBB, "InviterName", "second try",
			47, 3, 0).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 12 {
			t.Fatalf("dup-in: got %d, want 12", rc)
		}
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_offline WHERE user_id = $1 AND inviter_id = $2`,
			cidAddOffBA, cidAddOffBB).Scan(&cnt); err != nil {
			t.Fatalf("verify still 1: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("dup-in inserted phantom row: cnt=%d, want 1", cnt)
		}
	})

	t.Run("reverse-direction pending returns 19", func(t *testing.T) {
		// B has already invited A (seeded above). Now A tries to invite B.
		// NCSoft: A→B should return 19 because (user_id=B, inviter_id=A)
		// would be the row, but (user_id=A, inviter_id=B) already exists →
		// the second EXISTS check fires.
		var rc int
		if err := pool.CallSPRow(ctx, "aion_add_offline_buddy",
			cidAddOffBB, cidAddOffBA, "AsName", "reverse",
			47, 3, 0).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 19 {
			t.Fatalf("reverse: got %d, want 19", rc)
		}
	})

	t.Run("invitee at cap returns 14", func(t *testing.T) {
		// Saturate cidAddOffBCapInv with 100 active buddy_list rows.
		// 9002200..9002299 are dummy peer ids — no user_data row needed for
		// the cap math (count is on user_buddy_list rows, not joins).
		for i := 0; i < 100; i++ {
			peer := 9002200 + i
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0)
				 ON CONFLICT DO NOTHING`,
				cidAddOffBCapInv, peer); err != nil {
				t.Fatalf("saturate invitee: %v", err)
			}
		}

		var rc int
		if err := pool.CallSPRow(ctx, "aion_add_offline_buddy",
			cidAddOffBCapInv, cidAddOffBExtra, "tries", "you're full",
			1, 1, 0).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 14 {
			t.Fatalf("invitee cap: got %d, want 14", rc)
		}
		// No row inserted into user_buddy_offline.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_offline WHERE user_id = $1`,
			cidAddOffBCapInv).Scan(&cnt); err != nil {
			t.Fatalf("verify no-insert: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("invitee-cap inserted: cnt=%d, want 0", cnt)
		}
	})

	t.Run("inviter at cap returns 13", func(t *testing.T) {
		// Saturate cidAddOffBCapInvr's outbound roster (his own buddy list).
		// Reusing peer ids 9002200..9002299 is fine: they're peer keys, not
		// the cap-source — char_id = capInvr is what matters.
		for i := 0; i < 100; i++ {
			peer := 9002200 + i
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0)
				 ON CONFLICT DO NOTHING`,
				cidAddOffBCapInvr, peer); err != nil {
				t.Fatalf("saturate inviter: %v", err)
			}
		}

		var rc int
		// Use cidAddOffBExtra as the (uncapped) invitee. capInvr is the inviter.
		if err := pool.CallSPRow(ctx, "aion_add_offline_buddy",
			cidAddOffBExtra, cidAddOffBCapInvr, "Inviter", "I'm full",
			1, 1, 0).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 13 {
			t.Fatalf("inviter cap: got %d, want 13", rc)
		}
	})
}
