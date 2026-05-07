// Package database — integration test for aion_CommentList.
//
// Returns (comment_id, comment, writer, comment_date_unix) for the given
// char_id where deleted = 0, ordered by comment_id DESC. Test matrix:
//   - 3 active + 1 soft-deleted comment → returns the 3 actives
//     in DESC comment_id order (newest first)
//   - char with no comments → 0 rows
//   - comment_date is unix-seconds (positive bigint, close to "now")
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidCommentListA = 9001570 // owner with mixed live/deleted comments
	cidCommentListB = 9001571 // owner with no comments
)

func commentListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_comment WHERE char_id BETWEEN 9001570 AND 9001599`); err != nil {
		t.Fatalf("commentListCleanup user_comment: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001570 AND 9001599`); err != nil {
		t.Fatalf("commentListCleanup user_data: %v", err)
	}
}

func TestCommentList(t *testing.T) {
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

	commentListCleanup(t, ctx, pool)
	t.Cleanup(func() { commentListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidCommentListA, "ListOwnerA"},
		{cidCommentListB, "ListOwnerB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "cl_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// 3 actives + 1 soft-deleted. We capture the assigned BIGSERIAL ids so
	// we can assert the DESC ordering exactly without depending on the
	// sequence's starting value.
	insertComment := func(charID int, body, writer string, deleted int) int64 {
		t.Helper()
		var id int64
		if err := pool.Inner().QueryRow(ctx,
			`INSERT INTO user_comment(user_id, char_id, comment, writer, deleted)
			 VALUES ($1, $2, $3, $4, $5) RETURNING comment_id`,
			"uid_"+writer, charID, body, writer, deleted).Scan(&id); err != nil {
			t.Fatalf("insertComment: %v", err)
		}
		return id
	}
	id1 := insertComment(cidCommentListA, "first", "WriterA", 0)
	id2 := insertComment(cidCommentListA, "second", "WriterB", 0)
	idDel := insertComment(cidCommentListA, "ghost", "WriterC", 1) // soft-deleted, must NOT appear
	id3 := insertComment(cidCommentListA, "third", "WriterD", 0)
	_ = idDel

	t.Run("returns active rows in DESC order", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_commentlist", cidCommentListA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		var (
			ids       []int64
			comments  []string
			lastUnix  int64
			rowCount  int
			nowUnix   = time.Now().Unix()
		)
		for rows.Next() {
			var (
				cid       int64
				comment   string
				writer    string
				unixDate  int64
			)
			if err := rows.Scan(&cid, &comment, &writer, &unixDate); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			ids = append(ids, cid)
			comments = append(comments, comment)
			lastUnix = unixDate
			rowCount++
			// Comment_date should be a recent unix timestamp (within 60s),
			// which catches both unsigned-overflow and missing extract bugs.
			if unixDate <= 0 {
				t.Fatalf("comment_date non-positive: %d", unixDate)
			}
			if delta := nowUnix - unixDate; delta < -5 || delta > 60 {
				t.Fatalf("comment_date out of expected window: got %d (now=%d, delta=%d)",
					unixDate, nowUnix, delta)
			}
		}
		if rowCount != 3 {
			t.Fatalf("active row count: got %d, want 3 (deleted row must be filtered)", rowCount)
		}
		// DESC: id3 > id2 > id1.
		want := []int64{id3, id2, id1}
		for i, got := range ids {
			if got != want[i] {
				t.Fatalf("ord[%d]: got id=%d, want %d (full=%v want=%v)", i, got, want[i], ids, want)
			}
		}
		if comments[0] != "third" || comments[2] != "first" {
			t.Fatalf("comment-text DESC ordering: got %v", comments)
		}
		_ = lastUnix
	})

	t.Run("char with no comments returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_commentlist", cidCommentListB)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("empty owner: got %d rows, want 0", n)
		}
	})
}
