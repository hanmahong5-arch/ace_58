// Package database — integration test for aion_RemoveAllBuddy.
//
// Inbound-side cascade: when char X is purged, this SP DELETEs every row
// where buddy_id = X (i.e. strips X from all OTHER chars' lists). The
// outbound rows (X's own list) are NOT touched here — they're handled by
// the wider cm_delete_character cascade. Returns the number of rows deleted
// for diagnostic logging.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidRemBuddyTarget = 9001500 // the char being deleted
	cidRemBuddyOwnerA = 9001501 // friend who has Target on their list
	cidRemBuddyOwnerB = 9001502 // another friend who has Target
	cidRemBuddyUnrel  = 9001503 // unrelated char (control row)
)

func removeAllBuddyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_buddy_list WHERE char_id BETWEEN 9001500 AND 9001599 OR buddy_id BETWEEN 9001500 AND 9001599`); err != nil {
		t.Fatalf("removeAllBuddyCleanup buddy: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001500 AND 9001599`); err != nil {
		t.Fatalf("removeAllBuddyCleanup user_data: %v", err)
	}
}

func TestRemoveAllBuddy(t *testing.T) {
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

	removeAllBuddyCleanup(t, ctx, pool)
	t.Cleanup(func() { removeAllBuddyCleanup(t, context.Background(), pool) })

	// Seed 4 chars.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidRemBuddyTarget, "RemTgt"},
		{cidRemBuddyOwnerA, "RemOwnA"},
		{cidRemBuddyOwnerB, "RemOwnB"},
		{cidRemBuddyUnrel, "RemUnrel"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "rb_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Build the buddy graph:
	//   OwnerA → Target          (will be removed)
	//   OwnerB → Target          (will be removed)
	//   Target → OwnerA          (outbound, NOT touched by RemoveAllBuddy)
	//   OwnerA → Unrel           (control: must survive)
	insert := func(char, buddy int) {
		t.Helper()
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0)`,
			char, buddy); err != nil {
			t.Fatalf("seed buddy %d→%d: %v", char, buddy, err)
		}
	}
	insert(cidRemBuddyOwnerA, cidRemBuddyTarget)
	insert(cidRemBuddyOwnerB, cidRemBuddyTarget)
	insert(cidRemBuddyTarget, cidRemBuddyOwnerA)
	insert(cidRemBuddyOwnerA, cidRemBuddyUnrel)

	t.Run("inbound rows for target are deleted; outbound + control survive", func(t *testing.T) {
		var deleted int
		if err := pool.CallSPRow(ctx, "aion_removeallbuddy", cidRemBuddyTarget).Scan(&deleted); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if deleted != 2 {
			t.Fatalf("deleted=%d, want 2 (OwnerA→Target + OwnerB→Target)", deleted)
		}

		// Verify: no row anywhere with buddy_id = Target.
		var inboundCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_list WHERE buddy_id = $1`,
			cidRemBuddyTarget).Scan(&inboundCnt); err != nil {
			t.Fatalf("verify inbound: %v", err)
		}
		if inboundCnt != 0 {
			t.Fatalf("inbound survivors: got %d, want 0", inboundCnt)
		}

		// Outbound (Target → OwnerA) must still exist.
		var outboundCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_list WHERE char_id = $1`,
			cidRemBuddyTarget).Scan(&outboundCnt); err != nil {
			t.Fatalf("verify outbound: %v", err)
		}
		if outboundCnt != 1 {
			t.Fatalf("outbound count: got %d, want 1 (Target→OwnerA preserved)", outboundCnt)
		}

		// Control row OwnerA→Unrel survives.
		var controlCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidRemBuddyOwnerA, cidRemBuddyUnrel).Scan(&controlCnt); err != nil {
			t.Fatalf("verify control: %v", err)
		}
		if controlCnt != 1 {
			t.Fatalf("control row: got %d, want 1 (OwnerA→Unrel must survive)", controlCnt)
		}
	})

	t.Run("removing a char with no inbound rows returns 0", func(t *testing.T) {
		var deleted int
		// Unrel is on nobody's friend list.
		if err := pool.CallSPRow(ctx, "aion_removeallbuddy", cidRemBuddyUnrel).Scan(&deleted); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if deleted != 0 {
			t.Fatalf("deleted=%d, want 0 (no inbound rows)", deleted)
		}
	})
}
