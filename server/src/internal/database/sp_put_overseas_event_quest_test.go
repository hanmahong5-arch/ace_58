// Package database — integration test for aion_PutOverseasEventQuest.
//
// Plain INSERT into the **server-wide quest whitelist**. No char_id, no
// composite key — single-column row. Returns rows-affected (always 1 for a
// successful insert).
//
// Test matrix:
//   - first put inserts a row, returns 1
//   - second put with same quest_id ALSO inserts (T-SQL allows duplicates;
//     producer naively appends, consumer DISTINCTs on read — bug-for-bug)
//   - 3 distinct quest_ids → 3 rows
//   - all rows visible via direct SELECT (consumer can DISTINCT later)
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

// Sentinel quest_ids for this test (well outside any real quest range).
const (
	putOEQQuestA = 911001
	putOEQQuestB = 911002
	putOEQQuestC = 911003
)

func putOverseasEventQuestCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM overseas_event_quest WHERE quest_id BETWEEN 911000 AND 911099`); err != nil {
		t.Fatalf("putOverseasEventQuestCleanup overseas_event_quest: %v", err)
	}
}

func TestPutOverseasEventQuest(t *testing.T) {
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

	putOverseasEventQuestCleanup(t, ctx, pool)
	t.Cleanup(func() { putOverseasEventQuestCleanup(t, context.Background(), pool) })

	t.Run("first put inserts a row and returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putoverseaseventquest",
			putOEQQuestA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first put: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM overseas_event_quest WHERE quest_id = $1`,
			putOEQQuestA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rows after first put: got %d, want 1", cnt)
		}
	})

	t.Run("duplicate put on same quest_id ALSO inserts (bug-for-bug)", func(t *testing.T) {
		// T-SQL source: plain INSERT, no UNIQUE constraint, no UPSERT.
		// Producer (this SP) intentionally allows duplicates; consumer reads
		// with DISTINCT. Our PG port mirrors this exactly to preserve the
		// observable contract — if a future refactor wants idempotence,
		// add a UNIQUE constraint and switch the SP to ON CONFLICT DO NOTHING.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putoverseaseventquest",
			putOEQQuestA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 1 {
			t.Fatalf("duplicate put: got %d, want 1 (T-SQL allows dup)", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM overseas_event_quest WHERE quest_id = $1`,
			putOEQQuestA).Scan(&cnt); err != nil {
			t.Fatalf("count after dup: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("dup row count: got %d, want 2", cnt)
		}
	})

	t.Run("3 distinct quest_ids land as 3 rows in any order", func(t *testing.T) {
		// Wipe fixture to a clean state for this sub-test.
		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM overseas_event_quest WHERE quest_id BETWEEN 911000 AND 911099`); err != nil {
			t.Fatalf("inner-cleanup: %v", err)
		}

		for _, q := range []int{putOEQQuestA, putOEQQuestB, putOEQQuestC} {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putoverseaseventquest", q).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow q=%d: %v", q, err)
			}
			if affected != 1 {
				t.Fatalf("put q=%d: got %d, want 1", q, affected)
			}
		}

		rows, err := pool.Inner().Query(ctx,
			`SELECT quest_id FROM overseas_event_quest WHERE quest_id BETWEEN 911000 AND 911099`)
		if err != nil {
			t.Fatalf("Query: %v", err)
		}
		defer rows.Close()
		var got []int
		for rows.Next() {
			var q int
			if err := rows.Scan(&q); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, q)
		}
		sort.Ints(got)
		want := []int{putOEQQuestA, putOEQQuestB, putOEQQuestC}
		if len(got) != len(want) {
			t.Fatalf("row count: got %d, want %d (%v)", len(got), len(want), got)
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %d, want %d", i, got[i], w)
			}
		}
	})
}
