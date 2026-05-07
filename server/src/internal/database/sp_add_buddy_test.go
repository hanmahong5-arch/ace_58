// Package database — integration test for aion_AddBuddy.
//
// Buddy upsert SP: inserts (char_id, buddy_id) pair into user_buddy_list with
// delete_flag=0; ON CONFLICT DO NOTHING ensures duplicate calls are idempotent.
// Returns rows-inserted (0 or 1) so the caller can decide whether to push
// SM_FRIEND_LIST update events. Schema (table + SP) is created by the same
// migration (00144).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAddBuddyA = 9001400
	cidAddBuddyB = 9001401
	cidAddBuddyC = 9001402
)

func addBuddyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_buddy_list WHERE char_id BETWEEN 9001400 AND 9001499 OR buddy_id BETWEEN 9001400 AND 9001499`); err != nil {
		t.Fatalf("addBuddyCleanup buddy: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001400 AND 9001499`); err != nil {
		t.Fatalf("addBuddyCleanup user_data: %v", err)
	}
}

func TestAddBuddy(t *testing.T) {
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

	addBuddyCleanup(t, ctx, pool)
	t.Cleanup(func() { addBuddyCleanup(t, context.Background(), pool) })

	// Three test chars so we can exercise A→B + duplicate + bidirectional.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidAddBuddyA, "BuddyA"},
		{cidAddBuddyB, "BuddyB"},
		{cidAddBuddyC, "BuddyC"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "ab_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("first insert returns 1 and persists row", func(t *testing.T) {
		var inserted int
		if err := pool.CallSPRow(ctx, "aion_addbuddy", cidAddBuddyA, cidAddBuddyB).Scan(&inserted); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if inserted != 1 {
			t.Fatalf("first insert: got %d, want 1", inserted)
		}

		var deleteFlag int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT delete_flag FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidAddBuddyA, cidAddBuddyB).Scan(&deleteFlag); err != nil {
			t.Fatalf("verify row: %v", err)
		}
		if deleteFlag != 0 {
			t.Fatalf("delete_flag=%d, want 0", deleteFlag)
		}
	})

	t.Run("duplicate insert returns 0 (idempotent)", func(t *testing.T) {
		var inserted int
		if err := pool.CallSPRow(ctx, "aion_addbuddy", cidAddBuddyA, cidAddBuddyB).Scan(&inserted); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if inserted != 0 {
			t.Fatalf("duplicate insert: got %d, want 0", inserted)
		}
	})

	t.Run("reverse direction is independent (two-row friendship)", func(t *testing.T) {
		var inserted int
		// B → A is a separate row from A → B.
		if err := pool.CallSPRow(ctx, "aion_addbuddy", cidAddBuddyB, cidAddBuddyA).Scan(&inserted); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if inserted != 1 {
			t.Fatalf("reverse: got %d, want 1 (one-way row protocol)", inserted)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_list
			 WHERE (char_id = $1 AND buddy_id = $2) OR (char_id = $2 AND buddy_id = $1)`,
			cidAddBuddyA, cidAddBuddyB).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("bidirectional rows: cnt=%d, want 2", cnt)
		}
	})

	t.Run("third party add does not collide", func(t *testing.T) {
		var inserted int
		if err := pool.CallSPRow(ctx, "aion_addbuddy", cidAddBuddyA, cidAddBuddyC).Scan(&inserted); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if inserted != 1 {
			t.Fatalf("A→C: got %d, want 1", inserted)
		}
	})
}
