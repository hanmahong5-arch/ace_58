// Package database — integration test for aion_change_block_comment.
//
// Symmetric to aion_change_buddy_comment but operates on user_block (the
// 00072 scaffold already carries the comment column, so no schema delta).
// The two SPs share the same shape — UPDATE on (char_id, peer_id) returning
// rowcount — so we mirror the test matrix verbatim.
//
// Test matrix:
//   - first write returns 1 and persists
//   - overwrite returns 1; sibling row in same block list untouched
//   - non-existent pair returns 0 with no phantom insert
//   - empty string clears the note
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidChgBlkCmtOwner   = 9002000
	cidChgBlkCmtTargetA = 9002001
	cidChgBlkCmtTargetB = 9002002
)

func changeBlockCommentCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_block WHERE char_id BETWEEN 9002000 AND 9002099 OR block_id BETWEEN 9002000 AND 9002099`); err != nil {
		t.Fatalf("changeBlockCommentCleanup block: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9002000 AND 9002099`); err != nil {
		t.Fatalf("changeBlockCommentCleanup user_data: %v", err)
	}
}

func TestChangeBlockComment(t *testing.T) {
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

	changeBlockCommentCleanup(t, ctx, pool)
	t.Cleanup(func() { changeBlockCommentCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidChgBlkCmtOwner, "ChgBlkOwner"},
		{cidChgBlkCmtTargetA, "ChgBlkTgtA"},
		{cidChgBlkCmtTargetB, "ChgBlkTgtB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "cb_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Two block-list rows so we can prove sibling isolation.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_block(char_id, block_id, comment) VALUES ($1, $2, ''), ($1, $3, '')`,
		cidChgBlkCmtOwner, cidChgBlkCmtTargetA, cidChgBlkCmtTargetB); err != nil {
		t.Fatalf("seed block rows: %v", err)
	}

	t.Run("first write returns 1 and persists", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_block_comment",
			cidChgBlkCmtOwner, cidChgBlkCmtTargetA, "spammed me in market").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("first write: got %d, want 1", n)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidChgBlkCmtOwner, cidChgBlkCmtTargetA).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != "spammed me in market" {
			t.Fatalf("comment %q, want %q", got, "spammed me in market")
		}
	})

	t.Run("overwrite leaves sibling row alone", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_block_comment",
			cidChgBlkCmtOwner, cidChgBlkCmtTargetA, "still spamming").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("overwrite: got %d, want 1", n)
		}
		var sibling string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidChgBlkCmtOwner, cidChgBlkCmtTargetB).Scan(&sibling); err != nil {
			t.Fatalf("verify sibling: %v", err)
		}
		if sibling != "" {
			t.Fatalf("sibling leaked: %q, want empty", sibling)
		}
	})

	t.Run("non-existent pair returns 0 without insert", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_block_comment",
			cidChgBlkCmtOwner, 99999997, "ghost").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing pair: got %d, want 0", n)
		}
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidChgBlkCmtOwner, 99999997).Scan(&cnt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("phantom row: cnt=%d, want 0", cnt)
		}
	})

	t.Run("empty string clears existing note", func(t *testing.T) {
		var n int
		if err := pool.CallSPRow(ctx, "aion_change_block_comment",
			cidChgBlkCmtOwner, cidChgBlkCmtTargetA, "").Scan(&n); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if n != 1 {
			t.Fatalf("clear: got %d, want 1", n)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_block WHERE char_id = $1 AND block_id = $2`,
			cidChgBlkCmtOwner, cidChgBlkCmtTargetA).Scan(&got); err != nil {
			t.Fatalf("verify clear: %v", err)
		}
		if got != "" {
			t.Fatalf("cleared as %q, want empty", got)
		}
	})
}
