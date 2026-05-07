// Package database — integration test for aion_ReplaceAbnormalStatus.
//
// UPSERT on (char_id, skill_id) — sister of PutAbnormalStatus (00209). The
// IF EXISTS / UPDATE / ELSE INSERT shape collapses to ON CONFLICT … DO UPDATE.
//
// Test matrix:
//   - first call inserts 1 row (no prior state)
//   - second call same (char,skill) updates all 11 fields in place
//   - logout_time NOT bumped on update — pinned bug-for-bug from T-SQL
//   - distinct skill_ids on same char coexist
//   - neighbour isolation: A's replace doesn't perturb B
//
// char_id band: 9_530_010..9_530_019 (R15 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidReplaceAbnormalA = 9530010
	cidReplaceAbnormalB = 9530011
)

func replaceAbnormalStatusCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_abnormal_status WHERE char_id BETWEEN 9530010 AND 9530019`); err != nil {
		t.Fatalf("replaceAbnormalStatusCleanup user_abnormal_status: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9530010 AND 9530019`); err != nil {
		t.Fatalf("replaceAbnormalStatusCleanup user_data: %v", err)
	}
}

func TestReplaceAbnormalStatus(t *testing.T) {
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

	replaceAbnormalStatusCleanup(t, ctx, pool)
	t.Cleanup(func() { replaceAbnormalStatusCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidReplaceAbnormalA, "RplA"},
		{cidReplaceAbnormalB, "RplB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "rpl_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first call inserts 1 row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_replaceabnormalstatus",
			cidReplaceAbnormalA, int(3001), int16(2), int16(1),
			int(20000), int(15000), int(10000), int(5000),
			int(100), int(200), int(300), int(400),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow first: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status
			  WHERE char_id = $1 AND skill_id = $2`,
			cidReplaceAbnormalA, 3001).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("first cnt: got %d, want 1", cnt)
		}
	})

	t.Run("second call updates in place — all 11 fields overwritten", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_replaceabnormalstatus",
			cidReplaceAbnormalA, int(3001), int16(8), int16(3),
			int(99999), int(88888), int(77777), int(66666),
			int(1111), int(2222), int(3333), int(4444),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second affected: got %d, want 1", affected)
		}

		// Single row only — no duplicate inserted.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status
			  WHERE char_id = $1 AND skill_id = $2`,
			cidReplaceAbnormalA, 3001).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("upsert rows: got %d, want 1", cnt)
		}

		// All 11 fields must reflect the second call's payload.
		var (
			lvl, slot                               int16
			r1, r2, r3, r4, i1, i2, i3, i4 int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT skill_level, target_slot,
			        effect_remain1, effect_remain2, effect_remain3, effect_remain4,
			        interval_value1, interval_value2, interval_value3, interval_value4
			   FROM user_abnormal_status WHERE char_id = $1 AND skill_id = $2`,
			cidReplaceAbnormalA, 3001).Scan(&lvl, &slot,
			&r1, &r2, &r3, &r4, &i1, &i2, &i3, &i4); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if lvl != 8 || slot != 3 ||
			r1 != 99999 || r2 != 88888 || r3 != 77777 || r4 != 66666 ||
			i1 != 1111 || i2 != 2222 || i3 != 3333 || i4 != 4444 {
			t.Fatalf("update missed: lvl=%d slot=%d r=[%d %d %d %d] i=[%d %d %d %d]",
				lvl, slot, r1, r2, r3, r4, i1, i2, i3, i4)
		}
	})

	t.Run("logout_time NOT bumped on replace (bug-for-bug pin)", func(t *testing.T) {
		// The Replace branch does NOT touch logout_time — both T-SQL and our
		// PG port. The row was originally inserted by the Replace path with
		// logout_time defaulted to 0 (since Replace's INSERT branch omits it).
		// We verify it remains 0 after the second call updated all other fields.
		var lt int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT logout_time FROM user_abnormal_status
			  WHERE char_id = $1 AND skill_id = $2`,
			cidReplaceAbnormalA, 3001).Scan(&lt); err != nil {
			t.Fatalf("logout_time read: %v", err)
		}
		if lt != 0 {
			t.Fatalf("logout_time bumped on replace: got %d, want 0 (Replace must not touch it)", lt)
		}
	})

	t.Run("distinct skill_ids on same char coexist", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_replaceabnormalstatus",
			cidReplaceAbnormalA, int(3002), int16(1), int16(0),
			int(1), int(2), int(3), int(4),
			int(5), int(6), int(7), int(8),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second skill: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second skill: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id = $1`,
			cidReplaceAbnormalA).Scan(&cnt); err != nil {
			t.Fatalf("count A: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("two skills coexist: got %d rows, want 2", cnt)
		}
	})

	t.Run("neighbour isolation: A's replace doesn't perturb B", func(t *testing.T) {
		// Replace on B with same skill_id 3001 used on A — different char_id
		// must NOT collide.
		if err := pool.CallSPExec(ctx, "aion_replaceabnormalstatus",
			cidReplaceAbnormalB, int(3001), int16(99), int16(99),
			int(0), int(0), int(0), int(0),
			int(0), int(0), int(0), int(0)); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}

		// A's row still holds lvl=8 from the prior subtest.
		var lvlA int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT skill_level FROM user_abnormal_status
			  WHERE char_id = $1 AND skill_id = 3001`,
			cidReplaceAbnormalA).Scan(&lvlA); err != nil {
			t.Fatalf("verify A: %v", err)
		}
		if lvlA != 8 {
			t.Fatalf("A leaked from B: lvl=%d, want 8", lvlA)
		}

		// B has its own value.
		var lvlB int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT skill_level FROM user_abnormal_status
			  WHERE char_id = $1 AND skill_id = 3001`,
			cidReplaceAbnormalB).Scan(&lvlB); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if lvlB != 99 {
			t.Fatalf("B value: got %d, want 99", lvlB)
		}
	})
}
