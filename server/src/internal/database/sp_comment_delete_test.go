// Package database — integration test for aion_CommentDelete (tri-state flag).
//
// Tri-state contract:
//   _delete = 1 → soft-delete (set deleted = 1)
//   _delete = 2 → restore   (set deleted = 0)
//   _delete = anything else → no-op (returns 0 rows affected)
// Test verifies all three branches plus mismatched comment_id returns 0.
package database

import (
	"context"
	"testing"
	"time"
)

const cidCommentDelChar = 9001560

func commentDeleteCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_comment WHERE char_id BETWEEN 9001560 AND 9001599`); err != nil {
		t.Fatalf("commentDeleteCleanup user_comment: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001560 AND 9001599`); err != nil {
		t.Fatalf("commentDeleteCleanup user_data: %v", err)
	}
}

func TestCommentDelete(t *testing.T) {
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

	commentDeleteCleanup(t, ctx, pool)
	t.Cleanup(func() { commentDeleteCleanup(t, context.Background(), pool) })

	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
		cidCommentDelChar, "CommentDelOwner", "cd_owner"); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	// Insert a fresh comment per sub-test so flag transitions are independent.
	insertComment := func() int64 {
		t.Helper()
		var id int64
		if err := pool.Inner().QueryRow(ctx,
			`INSERT INTO user_comment(user_id, char_id, comment, writer)
			 VALUES ($1, $2, $3, $4) RETURNING comment_id`,
			"owner_uid", cidCommentDelChar, "hello", "GM").Scan(&id); err != nil {
			t.Fatalf("insertComment: %v", err)
		}
		return id
	}
	currentDeletedFlag := func(id int64) int {
		t.Helper()
		var d int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT deleted FROM user_comment WHERE comment_id = $1`, id).Scan(&d); err != nil {
			t.Fatalf("read deleted flag: %v", err)
		}
		return d
	}

	t.Run("delete=1 soft-deletes (deleted goes 0→1)", func(t *testing.T) {
		id := insertComment()
		var affected int
		if err := pool.CallSPRow(ctx, "aion_commentdelete", 1, id).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}
		if got := currentDeletedFlag(id); got != 1 {
			t.Fatalf("deleted flag after soft-delete: got %d, want 1", got)
		}
	})

	t.Run("delete=2 restores (deleted goes 1→0)", func(t *testing.T) {
		id := insertComment()
		// First flip to 1.
		if _, err := pool.Inner().Exec(ctx,
			`UPDATE user_comment SET deleted = 1 WHERE comment_id = $1`, id); err != nil {
			t.Fatalf("preflip: %v", err)
		}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_commentdelete", 2, id).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}
		if got := currentDeletedFlag(id); got != 0 {
			t.Fatalf("deleted flag after restore: got %d, want 0", got)
		}
	})

	t.Run("delete=0 (out-of-band) is silent no-op", func(t *testing.T) {
		id := insertComment()
		before := currentDeletedFlag(id)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_commentdelete", 0, id).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("affected for unknown flag: got %d, want 0", affected)
		}
		if got := currentDeletedFlag(id); got != before {
			t.Fatalf("flag mutated under unknown _delete: got %d, want %d", got, before)
		}
	})

	t.Run("mismatched comment_id touches no rows", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_commentdelete", 1, int64(999999999)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing comment_id: got %d, want 0", affected)
		}
	})
}
