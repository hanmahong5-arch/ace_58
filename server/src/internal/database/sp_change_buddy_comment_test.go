// Package database — integration test for aion_change_buddy_comment.
//
// Comment-update SP: writes user_buddy_list.comment for a (char_id, buddy_id)
// pair and returns rows-affected so the caller can skip a no-op SM_FRIEND_LIST
// refresh when the row doesn't exist. Schema column is added by the same
// migration (00149) — the AddBuddy migration (00144) had only the index keys.
//
// Test matrix:
//   - first write on an existing pair returns 1 and persists the text
//   - rewriting the same pair with a different string returns 1 and overwrites
//   - non-existent pair returns 0 and no row is created
//   - empty string is a valid comment (clears the note)
//   - Unicode payload (Korean / CJK) round-trips byte-for-byte
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidChgBuddyCmtA = 9001900
	cidChgBuddyCmtB = 9001901
	cidChgBuddyCmtC = 9001902
)

func changeBuddyCommentCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_buddy_list WHERE char_id BETWEEN 9001900 AND 9001999 OR buddy_id BETWEEN 9001900 AND 9001999`); err != nil {
		t.Fatalf("changeBuddyCommentCleanup buddy: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001900 AND 9001999`); err != nil {
		t.Fatalf("changeBuddyCommentCleanup user_data: %v", err)
	}
}

func TestChangeBuddyComment(t *testing.T) {
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

	changeBuddyCommentCleanup(t, ctx, pool)
	t.Cleanup(func() { changeBuddyCommentCleanup(t, context.Background(), pool) })

	// Seed three chars so we can assert that updating A→B leaves A→C alone.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidChgBuddyCmtA, "ChgBCmtA"},
		{cidChgBuddyCmtB, "ChgBCmtB"},
		{cidChgBuddyCmtC, "ChgBCmtC"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "cb_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Pre-populate two buddy rows so we can hit existing keys.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0), ($1, $3, 0)`,
		cidChgBuddyCmtA, cidChgBuddyCmtB, cidChgBuddyCmtC); err != nil {
		t.Fatalf("seed buddy rows: %v", err)
	}

	t.Run("first write returns 1 and persists comment", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_buddy_comment",
			cidChgBuddyCmtA, cidChgBuddyCmtB, "Tank — main healer alt").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("first write: got %d, want 1", n)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidChgBuddyCmtA, cidChgBuddyCmtB).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != "Tank — main healer alt" {
			t.Fatalf("comment persisted as %q, want %q", got, "Tank — main healer alt")
		}
	})

	t.Run("overwrite returns 1 and replaces previous text", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_buddy_comment",
			cidChgBuddyCmtA, cidChgBuddyCmtB, "switched to DPS spec").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("overwrite: got %d, want 1", n)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidChgBuddyCmtA, cidChgBuddyCmtB).Scan(&got); err != nil {
			t.Fatalf("verify overwrite: %v", err)
		}
		if got != "switched to DPS spec" {
			t.Fatalf("overwritten comment %q, want %q", got, "switched to DPS spec")
		}

		// Sibling row A→C must remain at its default empty comment.
		var sibling string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidChgBuddyCmtA, cidChgBuddyCmtC).Scan(&sibling); err != nil {
			t.Fatalf("verify sibling: %v", err)
		}
		if sibling != "" {
			t.Fatalf("sibling row leaked update: comment=%q, want empty", sibling)
		}
	})

	t.Run("non-existent pair returns 0 with no row created", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_buddy_comment",
			cidChgBuddyCmtA, 99999998, "ghost").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing pair: got %d, want 0", n)
		}
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidChgBuddyCmtA, 99999998).Scan(&cnt); err != nil {
			t.Fatalf("verify no insert: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("phantom row created: cnt=%d, want 0", cnt)
		}
	})

	t.Run("empty string clears note", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_buddy_comment",
			cidChgBuddyCmtA, cidChgBuddyCmtB, "").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("clear: got %d, want 1", n)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidChgBuddyCmtA, cidChgBuddyCmtB).Scan(&got); err != nil {
			t.Fatalf("verify clear: %v", err)
		}
		if got != "" {
			t.Fatalf("cleared comment %q, want empty", got)
		}
	})

	t.Run("CJK Unicode round-trips intact", func(t *testing.T) {
		const cjk = "탱커 — 메인 힐러의 부캐 (战友)"
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_buddy_comment",
			cidChgBuddyCmtA, cidChgBuddyCmtB, cjk).Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("cjk write: got %d, want 1", n)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidChgBuddyCmtA, cidChgBuddyCmtB).Scan(&got); err != nil {
			t.Fatalf("verify cjk: %v", err)
		}
		if got != cjk {
			t.Fatalf("CJK round-trip: got %q, want %q", got, cjk)
		}
	})
}
