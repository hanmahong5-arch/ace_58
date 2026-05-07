// Package database — integration test for aion_DeleteAllOverseasEventQuest.
//
// Wholesale wipe of the overseas-event quest **whitelist** (no args, no
// filter). Returns rows-affected for telemetry. Used by the GM tool when a
// new event cycle begins: clear, re-seed, ship.
//
// Test matrix:
//   - sweep with seeded rows → returns N (= seeded count), table empty after
//   - second sweep on empty table → returns 0 (idempotent)
//   - re-seed after sweep works (whitelist becomes the new set)
//
// NOTE: this SP wipes the *whole* overseas_event_quest table, not just our
// fixture rows. To stay isolated from concurrent tests we run with a fresh
// migration in this DB and assert on what we know we put in.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	delAllOEQQ1 = 912001
	delAllOEQQ2 = 912002
	delAllOEQQ3 = 912003
)

func deleteAllOverseasEventQuestCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	// The SP itself wipes the table; we still scrub our sentinel range to
	// keep the test independent of order-of-execution and to avoid leaking
	// rows into other tests if this one panics partway.
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM overseas_event_quest WHERE quest_id BETWEEN 912000 AND 912099`); err != nil {
		t.Fatalf("deleteAllOverseasEventQuestCleanup overseas_event_quest: %v", err)
	}
}

func TestDeleteAllOverseasEventQuest(t *testing.T) {
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

	// Pre-test: snapshot the row count of the whole table so we can assert
	// post-sweep state independently of any rows the test DB may contain.
	deleteAllOverseasEventQuestCleanup(t, ctx, pool)
	t.Cleanup(func() { deleteAllOverseasEventQuestCleanup(t, context.Background(), pool) })

	t.Run("sweep with seeded rows returns >= seeded count and empties table", func(t *testing.T) {
		// Seed 3 rows in our sentinel range.
		for _, q := range []int{delAllOEQQ1, delAllOEQQ2, delAllOEQQ3} {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO overseas_event_quest(quest_id) VALUES ($1)`, q); err != nil {
				t.Fatalf("seed q=%d: %v", q, err)
			}
		}

		// Capture total row count in the whole table just before sweep so we
		// can predict the SP's exact return value (the SP DELETEs everything,
		// not just our 3 rows).
		var beforeCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM overseas_event_quest`).Scan(&beforeCnt); err != nil {
			t.Fatalf("count before: %v", err)
		}
		if beforeCnt < 3 {
			t.Fatalf("pre-sweep count: got %d, want >= 3 (our 3 seeds)", beforeCnt)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletealloverseaseventquest").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != beforeCnt {
			t.Fatalf("sweep with rows: got %d, want %d (whole-table count)", affected, beforeCnt)
		}

		// Table fully empty afterwards.
		var afterCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM overseas_event_quest`).Scan(&afterCnt); err != nil {
			t.Fatalf("count after: %v", err)
		}
		if afterCnt != 0 {
			t.Fatalf("post-sweep count: got %d, want 0", afterCnt)
		}
	})

	t.Run("idempotent: second sweep on empty table returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletealloverseaseventquest").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 0 {
			t.Fatalf("second sweep: got %d, want 0", affected)
		}
	})

	t.Run("re-seed after sweep works (whitelist replaceable)", func(t *testing.T) {
		// Use the producer SP (00186) so this also functions as a smoke test
		// of the put → delete-all → put cycle that the real GM tool exercises.
		var put int
		if err := pool.CallSPRow(ctx, "aion_putoverseaseventquest",
			delAllOEQQ1).Scan(&put); err != nil {
			t.Fatalf("re-seed put: %v", err)
		}
		if put != 1 {
			t.Fatalf("re-seed put: got %d, want 1", put)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM overseas_event_quest WHERE quest_id = $1`,
			delAllOEQQ1).Scan(&cnt); err != nil {
			t.Fatalf("verify re-seed: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("re-seed cnt: got %d, want 1", cnt)
		}
	})
}
