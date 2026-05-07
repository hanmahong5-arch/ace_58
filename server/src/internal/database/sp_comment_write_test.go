// Package database — integration test for aion_CommentWrite.
//
// Inserts a row into user_comment and returns the BIGSERIAL comment_id of
// the new row (PG equivalent of T-SQL @@IDENTITY). Verifies:
//   - returned id is positive and matches the row that was actually written
//   - all four input fields round-trip verbatim
//   - comment_date auto-fills (NOW() default in 00156)
//   - sequential calls yield strictly-increasing ids
//   - new row defaults deleted = 0 so it shows up in CommentList by default
package database

import (
	"context"
	"testing"
	"time"
)

const cidCommentWriteChar = 9001580

func commentWriteCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_comment WHERE char_id BETWEEN 9001580 AND 9001599`); err != nil {
		t.Fatalf("commentWriteCleanup user_comment: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001580 AND 9001599`); err != nil {
		t.Fatalf("commentWriteCleanup user_data: %v", err)
	}
}

func TestCommentWrite(t *testing.T) {
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

	commentWriteCleanup(t, ctx, pool)
	t.Cleanup(func() { commentWriteCleanup(t, context.Background(), pool) })

	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
		cidCommentWriteChar, "WriteTarget", "wt_owner"); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	t.Run("first write returns positive id, row persists with all fields", func(t *testing.T) {
		var id int64
		if err := pool.CallSPRow(ctx, "aion_commentwrite",
			"author_uid_001", cidCommentWriteChar, "hello world", "AlphaWriter").Scan(&id); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if id <= 0 {
			t.Fatalf("returned id non-positive: %d", id)
		}

		var (
			gotUserID  string
			gotCharID  int
			gotComment string
			gotWriter  string
			gotDeleted int
			gotDate    time.Time
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT user_id, char_id, comment, writer, deleted, comment_date
			   FROM user_comment WHERE comment_id = $1`, id).Scan(
			&gotUserID, &gotCharID, &gotComment, &gotWriter, &gotDeleted, &gotDate); err != nil {
			t.Fatalf("verify row: %v", err)
		}
		if gotUserID != "author_uid_001" || gotCharID != cidCommentWriteChar ||
			gotComment != "hello world" || gotWriter != "AlphaWriter" {
			t.Fatalf("field round-trip: got (%q,%d,%q,%q), want (author_uid_001,%d,hello world,AlphaWriter)",
				gotUserID, gotCharID, gotComment, gotWriter, cidCommentWriteChar)
		}
		if gotDeleted != 0 {
			t.Fatalf("default deleted: got %d, want 0", gotDeleted)
		}
		if delta := time.Since(gotDate); delta < 0 || delta > time.Minute {
			t.Fatalf("comment_date out of expected window: got %v (delta=%v)", gotDate, delta)
		}
	})

	t.Run("sequential writes yield strictly-increasing ids", func(t *testing.T) {
		var prev int64 = -1
		for i := 0; i < 3; i++ {
			var id int64
			if err := pool.CallSPRow(ctx, "aion_commentwrite",
				"uid_seq", cidCommentWriteChar, "seq_msg", "SeqWriter").Scan(&id); err != nil {
				t.Fatalf("CallSPRow seq[%d]: %v", i, err)
			}
			if id <= prev {
				t.Fatalf("id not strictly increasing: prev=%d got=%d", prev, id)
			}
			prev = id
		}
	})

	t.Run("new row appears in aion_commentlist (deleted=0 default)", func(t *testing.T) {
		// Establish a baseline count for this char then write one more and
		// confirm the count grows by exactly 1 — proves the cross-SP contract
		// (Write defaults deleted=0 → List returns it).
		var baseline int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_comment WHERE char_id = $1 AND deleted = 0`,
			cidCommentWriteChar).Scan(&baseline); err != nil {
			t.Fatalf("baseline count: %v", err)
		}

		var id int64
		if err := pool.CallSPRow(ctx, "aion_commentwrite",
			"final_uid", cidCommentWriteChar, "final", "FinalWriter").Scan(&id); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}

		// Use the production SP for the read-side, not a hand-written SELECT,
		// so this test also covers the List ↔ Write contract.
		rows, err := pool.CallSP(ctx, "aion_commentlist", cidCommentWriteChar)
		if err != nil {
			t.Fatalf("CallSP list: %v", err)
		}
		defer rows.Close()
		var listCnt int
		var sawWrittenID bool
		for rows.Next() {
			var (
				cid     int64
				comment string
				writer  string
				date    int64
			)
			if err := rows.Scan(&cid, &comment, &writer, &date); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			listCnt++
			if cid == id {
				sawWrittenID = true
			}
		}
		if listCnt != baseline+1 {
			t.Fatalf("list count: got %d, want baseline+1 = %d", listCnt, baseline+1)
		}
		if !sawWrittenID {
			t.Fatalf("List did not return the just-written id %d", id)
		}
	})
}
