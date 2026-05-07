// Package database — integration test for aion_PutChallengeTask.
//
// 3-way return-code SP with OUT param task_db_id:
//   rc=0: success (task_db_id = newly minted BIGSERIAL id)
//   rc=1: duplicate (task_db_id NULL)
//   rc=2: insert failure (task_db_id NULL) — exercised via deliberately
//         broken arg in a future expansion; current matrix asserts the
//         observable rc=0/1 paths since rc=2 requires forced PG error injection
//         which is out of scope for a pure-SP test.
//
// Test matrix:
//   - first put on (union, type, name) → rc=0, task_db_id non-zero
//   - duplicate (same triplet) → rc=1, task_db_id NULL
//   - distinct (union, type, name) → rc=0, fresh id (monotonically increasing)
//   - neighbour isolation: union A and union B can hold the same (type, name)
//   - rc=0 row materialises with default complete_count=0 + last_complete_time=0
package database

import (
	"context"
	"database/sql"
	"testing"
	"time"
)

const (
	unionChallengeA = 9520021
	unionChallengeB = 9520022
)

func putChallengeTaskCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM challenge_task WHERE union_id BETWEEN 9520021 AND 9520099`); err != nil {
		t.Fatalf("putChallengeTaskCleanup challenge_task: %v", err)
	}
}

func TestPutChallengeTask(t *testing.T) {
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

	putChallengeTaskCleanup(t, ctx, pool)
	t.Cleanup(func() { putChallengeTaskCleanup(t, context.Background(), pool) })

	t.Run("first put → rc=0, task_db_id non-zero", func(t *testing.T) {
		var (
			rc      int
			taskID  sql.NullInt64
		)
		if err := pool.CallSPRow(ctx, "aion_putchallengetask",
			int32(unionChallengeA), int16(1), int32(101), int16(0),
		).Scan(&rc, &taskID); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != 0 {
			t.Fatalf("first rc: got %d, want 0", rc)
		}
		if !taskID.Valid || taskID.Int64 == 0 {
			t.Fatalf("task_db_id: got %+v, want non-zero valid bigint", taskID)
		}

		// Verify the row materialised with the default flags.
		var (
			status         int16
			completeCount  int32
			lastCompleteTs int32
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT status, complete_count, last_complete_time
			   FROM challenge_task WHERE id = $1`, taskID.Int64,
		).Scan(&status, &completeCount, &lastCompleteTs); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if status != 0 || completeCount != 0 || lastCompleteTs != 0 {
			t.Fatalf("row defaults: got status=%d cnt=%d ts=%d, want 0/0/0",
				status, completeCount, lastCompleteTs)
		}
	})

	t.Run("duplicate (same triplet) → rc=1, task_db_id NULL", func(t *testing.T) {
		var (
			rc      int
			taskID  sql.NullInt64
		)
		// Replay the same (union, type, name) — must be rejected as duplicate.
		if err := pool.CallSPRow(ctx, "aion_putchallengetask",
			int32(unionChallengeA), int16(1), int32(101), int16(0),
		).Scan(&rc, &taskID); err != nil {
			t.Fatalf("CallSPRow dup: %v", err)
		}
		if rc != 1 {
			t.Fatalf("dup rc: got %d, want 1", rc)
		}
		if taskID.Valid {
			t.Fatalf("dup task_db_id: got %d valid, want NULL", taskID.Int64)
		}

		// Confirm the table didn't grow a second row.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM challenge_task
			  WHERE union_id = $1 AND type = $2 AND task_name_id = $3`,
			unionChallengeA, 1, 101).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("dup row leak: got %d, want 1", cnt)
		}
	})

	t.Run("distinct (union, type, name) → rc=0 with fresh monotonic id", func(t *testing.T) {
		// First grant: type=1, name=102 (different from earlier 101).
		var (
			rc1, rc2     int
			taskID1, id2 sql.NullInt64
		)
		if err := pool.CallSPRow(ctx, "aion_putchallengetask",
			int32(unionChallengeA), int16(1), int32(102), int16(0),
		).Scan(&rc1, &taskID1); err != nil {
			t.Fatalf("CallSPRow distinct1: %v", err)
		}
		if rc1 != 0 || !taskID1.Valid {
			t.Fatalf("distinct1: rc=%d id=%+v, want 0 + non-null", rc1, taskID1)
		}

		// Second grant: type=2, name=101 (different type than the first SP put).
		if err := pool.CallSPRow(ctx, "aion_putchallengetask",
			int32(unionChallengeA), int16(2), int32(101), int16(0),
		).Scan(&rc2, &id2); err != nil {
			t.Fatalf("CallSPRow distinct2: %v", err)
		}
		if rc2 != 0 || !id2.Valid {
			t.Fatalf("distinct2: rc=%d id=%+v, want 0 + non-null", rc2, id2)
		}

		// Ids are monotonic — BIGSERIAL guarantees no rollback gap-free, but
		// id2 must be strictly greater than taskID1.
		if id2.Int64 <= taskID1.Int64 {
			t.Fatalf("monotonic id: id1=%d id2=%d (want id2 > id1)",
				taskID1.Int64, id2.Int64)
		}
	})

	t.Run("neighbour isolation: union A and union B share (type, name)", func(t *testing.T) {
		// Union A already has (type=1, name=101). Insert it under union B.
		// Different union_id → not a duplicate → rc=0.
		var (
			rc     int
			taskID sql.NullInt64
		)
		if err := pool.CallSPRow(ctx, "aion_putchallengetask",
			int32(unionChallengeB), int16(1), int32(101), int16(0),
		).Scan(&rc, &taskID); err != nil {
			t.Fatalf("CallSPRow neighbour: %v", err)
		}
		if rc != 0 || !taskID.Valid {
			t.Fatalf("neighbour: rc=%d id=%+v, want 0 + non-null", rc, taskID)
		}

		// Both union_ids hold a (1, 101) row — verify directly.
		var aCnt, bCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM challenge_task
			  WHERE union_id = $1 AND type = 1 AND task_name_id = 101`,
			unionChallengeA).Scan(&aCnt); err != nil {
			t.Fatalf("count A: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM challenge_task
			  WHERE union_id = $1 AND type = 1 AND task_name_id = 101`,
			unionChallengeB).Scan(&bCnt); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if aCnt != 1 || bCnt != 1 {
			t.Fatalf("neighbour rows: A=%d B=%d, want 1/1", aCnt, bCnt)
		}
	})
}
