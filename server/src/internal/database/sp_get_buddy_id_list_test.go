// Package database — integration test for aion_GetBuddyIdList.
//
// STABLE query SP: returns buddy_id rows for char_id where delete_flag = 0.
// Test matrix:
//   - char with multiple active buddies returns full set
//   - soft-deleted (delete_flag=1) rows are filtered out
//   - char with no buddies returns 0 rows
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidGetBuddyOwner    = 9001700
	cidGetBuddyFriendA  = 9001701
	cidGetBuddyFriendB  = 9001702
	cidGetBuddyDeleted  = 9001703
	cidGetBuddyOrphan   = 9001704
)

func getBuddyIDListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_buddy_list WHERE char_id BETWEEN 9001700 AND 9001799 OR buddy_id BETWEEN 9001700 AND 9001799`); err != nil {
		t.Fatalf("getBuddyIDListCleanup buddy: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001700 AND 9001799`); err != nil {
		t.Fatalf("getBuddyIDListCleanup user_data: %v", err)
	}
}

func TestGetBuddyIdList(t *testing.T) {
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

	getBuddyIDListCleanup(t, ctx, pool)
	t.Cleanup(func() { getBuddyIDListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidGetBuddyOwner, "GBOwner"},
		{cidGetBuddyFriendA, "GBFriendA"},
		{cidGetBuddyFriendB, "GBFriendB"},
		{cidGetBuddyDeleted, "GBDeleted"},
		{cidGetBuddyOrphan, "GBOrphan"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "gb_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Owner has 2 active buddies + 1 soft-deleted.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES
		 ($1, $2, 0), ($1, $3, 0), ($1, $4, 1)`,
		cidGetBuddyOwner, cidGetBuddyFriendA, cidGetBuddyFriendB, cidGetBuddyDeleted); err != nil {
		t.Fatalf("seed buddy rows: %v", err)
	}

	t.Run("active buddies returned, soft-deleted filtered", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getbuddyidlist", cidGetBuddyOwner)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var got []int
		for rows.Next() {
			var b int
			if err := rows.Scan(&b); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, b)
		}
		sort.Ints(got)
		want := []int{cidGetBuddyFriendA, cidGetBuddyFriendB}
		if len(got) != 2 || got[0] != want[0] || got[1] != want[1] {
			t.Fatalf("active list: got %v, want %v (deleted should be filtered)", got, want)
		}
	})

	t.Run("char with no buddies returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getbuddyidlist", cidGetBuddyOrphan)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("orphan: got %d rows, want 0", n)
		}
	})

	t.Run("non-existent char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getbuddyidlist", 99999999)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing: got %d rows, want 0", n)
		}
	})
}
