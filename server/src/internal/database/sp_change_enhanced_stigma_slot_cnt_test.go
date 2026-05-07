// Package database — integration test for aion_ChangeEnhancedStigmaSlotCnt.
//
// 3-way return contract pinned bug-for-bug:
//   -1 = char not found OR scheduled-for-deletion deadline already past
//    0 = update raised an error (PG: caught by EXCEPTION handler)
//   @nCharID = success ("echo on success" idiom — caller verifies rc == char_id)
//
// Test matrix:
//   - happy path (alive char): rc == char_id, slot count updated
//   - missing char: rc == -1
//   - scheduled-for-deletion in future (delete_date > now): row STILL guarded
//     out — bug-for-bug pinned (T-SQL: deletion-pending blocks updates)
//   - delete_date=0 explicitly accepted (alive forever path)
//   - boundary: cnt=0 (slot reset) and cnt=255 (TINYINT max in T-SQL)
//   - neighbour isolation: A's update doesn't perturb B
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidStigmaA              = 9520041 // alive (delete_date=0)
	cidStigmaB              = 9520042 // alive (delete_date=0)
	cidStigmaScheduledDel   = 9520043 // delete_date > now → blocked
	cidStigmaPastDel        = 9520044 // delete_date < now → looks "alive forever" via T-SQL guard? NO — T-SQL guard is "delete_date=0 OR delete_date>now". Past delete_date makes the char DEAD.
	cidStigmaMissing        = 9520099 // never seeded
)

func changeEnhancedStigmaCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9520041 AND 9520099`); err != nil {
		t.Fatalf("changeEnhancedStigmaCleanup user_data: %v", err)
	}
}

func TestChangeEnhancedStigmaSlotCnt(t *testing.T) {
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

	changeEnhancedStigmaCleanup(t, ctx, pool)
	t.Cleanup(func() { changeEnhancedStigmaCleanup(t, context.Background(), pool) })

	// Future deadline (1 year out) and past deadline (1 year ago).
	nowEpoch := time.Now().Unix()
	futureDel := int32(nowEpoch + 365*24*3600)
	pastDel := int32(nowEpoch - 365*24*3600)

	// Seed the four "real" chars + one "missing" via deliberate skip.
	type seed struct {
		id        int
		name      string
		deleteDate int32
	}
	for _, s := range []seed{
		{cidStigmaA, "StigA", 0},
		{cidStigmaB, "StigB", 0},
		{cidStigmaScheduledDel, "StigSched", futureDel},
		{cidStigmaPastDel, "StigPast", pastDel},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, delete_date)
			 VALUES ($1, $2, $3, $4)`,
			s.id, s.name, "stig_"+s.name, s.deleteDate); err != nil {
			t.Fatalf("seed %s: %v", s.name, err)
		}
	}

	t.Run("happy path: alive char → rc == char_id, slot updated", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaA, int16(3)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if rc != cidStigmaA {
			t.Fatalf("rc: got %d, want %d (echo-on-success)", rc, cidStigmaA)
		}

		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaA).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 3 {
			t.Fatalf("slot cnt: got %d, want 3", got)
		}
	})

	t.Run("missing char → rc == -1", func(t *testing.T) {
		var rc int
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaMissing, int16(2)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if rc != -1 {
			t.Fatalf("missing rc: got %d, want -1", rc)
		}
	})

	t.Run("scheduled-for-deletion in future → SP allows update (delete_date>now)", func(t *testing.T) {
		// Bug-for-bug clarification: T-SQL guard is
		//   delete_date = 0 OR (delete_date > GetUnixtimeWithUTCAdjust(GetUTCDate(),0))
		// "delete_date > now" means the deletion is STILL in the future
		// → grace window → char IS reachable → SP DOES update.
		// (Past delete_date is what blocks it; that's the next subtest.)
		var rc int
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaScheduledDel, int16(4)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow scheduled: %v", err)
		}
		if rc != cidStigmaScheduledDel {
			t.Fatalf("scheduled rc: got %d, want %d (grace window allows update)",
				rc, cidStigmaScheduledDel)
		}

		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaScheduledDel).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 4 {
			t.Fatalf("scheduled slot cnt: got %d, want 4", got)
		}
	})

	t.Run("past-deadline char → rc == -1 (deletion already lapsed)", func(t *testing.T) {
		// delete_date < now → guard returns false → char treated as dead.
		var rc int
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaPastDel, int16(5)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow past: %v", err)
		}
		if rc != -1 {
			t.Fatalf("past rc: got %d, want -1 (past deadline = dead)", rc)
		}

		// Confirm the slot was NOT updated.
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaPastDel).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 0 {
			t.Fatalf("past slot leak: got %d, want 0 (no update)", got)
		}
	})

	t.Run("boundary: cnt=0 (slot reset) and cnt=255 (TINYINT max)", func(t *testing.T) {
		// cnt = 0 — explicit reset.
		var rc int
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaA, int16(0)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow cnt=0: %v", err)
		}
		if rc != cidStigmaA {
			t.Fatalf("cnt=0 rc: got %d, want %d", rc, cidStigmaA)
		}
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaA).Scan(&got); err != nil {
			t.Fatalf("verify cnt=0: %v", err)
		}
		if got != 0 {
			t.Fatalf("cnt=0 stored: got %d, want 0", got)
		}

		// cnt = 255 — TINYINT max in T-SQL; SMALLINT can hold it.
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaA, int16(255)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow cnt=255: %v", err)
		}
		if rc != cidStigmaA {
			t.Fatalf("cnt=255 rc: got %d, want %d", rc, cidStigmaA)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaA).Scan(&got); err != nil {
			t.Fatalf("verify cnt=255: %v", err)
		}
		if got != 255 {
			t.Fatalf("cnt=255 stored: got %d, want 255", got)
		}
	})

	t.Run("neighbour isolation: A's update doesn't perturb B", func(t *testing.T) {
		// B should still hold its default 0 — never been touched in this test.
		var got int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaB).Scan(&got); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if got != 0 {
			t.Fatalf("B leaked from A: got %d, want 0", got)
		}

		// Now bump B independently, A should still hold 255 from boundary case.
		var rc int
		if err := pool.CallSPRow(ctx, "aion_changeenhancedstigmaslotcnt",
			cidStigmaB, int16(7)).Scan(&rc); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if rc != cidStigmaB {
			t.Fatalf("B rc: got %d, want %d", rc, cidStigmaB)
		}

		var aGot int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enhanced_stigma_slot_cnt FROM user_data WHERE char_id = $1`,
			cidStigmaA).Scan(&aGot); err != nil {
			t.Fatalf("verify A intact: %v", err)
		}
		if aGot != 255 {
			t.Fatalf("A leaked from B: got %d, want 255", aGot)
		}
	})
}
