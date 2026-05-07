// Package database — integration test for aion_PutAbnormalStatus.
//
// Pure INSERT into user_abnormal_status (one row per (char_id, skill_id) under
// the R7 PK alignment from 00209). PutAbnormalStatus is the "fresh insert"
// path used at logout snapshot replay; ReplaceAbnormalStatus (00210) handles
// the upsert path.
//
// Test matrix:
//   - happy path: first put inserts 1 row, full column round-trip, logout_time stamped
//   - distinct skill_ids on same char coexist (multiple buffs)
//   - duplicate (char_id, skill_id) raises unique_violation (bug-for-bug pin)
//   - neighbour isolation: A's puts don't leak into B
//   - missing user_data: PutAbnormalStatus still succeeds (no FK)
//
// char_id band: 9_530_001..9_530_099 (R15 batch, avoiding R10/R13/R14 bands).
package database

import (
	"context"
	"strings"
	"testing"
	"time"
)

const (
	cidPutAbnormalA       = 9530001
	cidPutAbnormalB       = 9530002
	cidPutAbnormalMissing = 9530099 // intentionally NOT seeded (orphan-insert canary)
)

func putAbnormalStatusCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_abnormal_status WHERE char_id BETWEEN 9530001 AND 9530099`); err != nil {
		t.Fatalf("putAbnormalStatusCleanup user_abnormal_status: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9530001 AND 9530099`); err != nil {
		t.Fatalf("putAbnormalStatusCleanup user_data: %v", err)
	}
}

func TestPutAbnormalStatus(t *testing.T) {
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

	putAbnormalStatusCleanup(t, ctx, pool)
	t.Cleanup(func() { putAbnormalStatusCleanup(t, context.Background(), pool) })

	// Seed parents for A/B; Missing intentionally absent to verify no-FK behaviour.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidPutAbnormalA, "AbnA"},
		{cidPutAbnormalB, "AbnB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "abn_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: first put inserts, full column round-trip", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putabnormalstatus",
			cidPutAbnormalA, int(1001), int16(5), int16(2),
			int(60000), int(50000), int(40000), int(30000),
			int(1000), int(2000), int(3000), int(4000),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var (
			skillID, r1, r2, r3, r4, i1, i2, i3, i4 int
			lvl, slot                               int16
			logoutTime                              int64
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT skill_id, skill_level, target_slot,
			        effect_remain1, effect_remain2, effect_remain3, effect_remain4,
			        interval_value1, interval_value2, interval_value3, interval_value4,
			        logout_time
			   FROM user_abnormal_status WHERE char_id = $1 AND skill_id = $2`,
			cidPutAbnormalA, 1001).Scan(&skillID, &lvl, &slot,
			&r1, &r2, &r3, &r4, &i1, &i2, &i3, &i4, &logoutTime); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if skillID != 1001 || lvl != 5 || slot != 2 ||
			r1 != 60000 || r2 != 50000 || r3 != 40000 || r4 != 30000 ||
			i1 != 1000 || i2 != 2000 || i3 != 3000 || i4 != 4000 {
			t.Fatalf("column round-trip mismatch: skill=%d lvl=%d slot=%d r=[%d %d %d %d] i=[%d %d %d %d]",
				skillID, lvl, slot, r1, r2, r3, r4, i1, i2, i3, i4)
		}
		// logout_time must be within ±10s of host now (epoch seconds).
		nowEpoch := time.Now().Unix()
		if logoutTime < nowEpoch-10 || logoutTime > nowEpoch+10 {
			t.Fatalf("logout_time drift: got %d, host now %d", logoutTime, nowEpoch)
		}
	})

	t.Run("distinct skill_ids on same char coexist", func(t *testing.T) {
		// skill 1001 already inserted above; add 1002 + 1003 — must not collide.
		for _, sk := range []int{1002, 1003} {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putabnormalstatus",
				cidPutAbnormalA, sk, int16(1), int16(0),
				int(10000), int(0), int(0), int(0),
				int(0), int(0), int(0), int(0),
			).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow skill=%d: %v", sk, err)
			}
			if affected != 1 {
				t.Fatalf("skill=%d: got %d, want 1", sk, affected)
			}
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id = $1`,
			cidPutAbnormalA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 3 {
			t.Fatalf("3 buffs on same char: got %d rows, want 3", cnt)
		}
	})

	t.Run("duplicate (char_id, skill_id) raises unique_violation", func(t *testing.T) {
		// Re-inserting skill 1001 on cidPutAbnormalA must fail by PK collision —
		// PutAbnormalStatus is the pure-INSERT path; ReplaceAbnormalStatus is the
		// upsert path. Bug-for-bug pin: T-SQL raises a PK error here.
		_, err := pool.Inner().Exec(ctx,
			`SELECT aion_putabnormalstatus($1, $2, $3::SMALLINT, $4::SMALLINT,
			                               $5, $6, $7, $8, $9, $10, $11, $12)`,
			cidPutAbnormalA, 1001, 5, 2,
			60000, 50000, 40000, 30000,
			1000, 2000, 3000, 4000)
		if err == nil {
			t.Fatalf("dup insert: want unique_violation, got nil")
		}
		// Postgres surfaces it as SQLSTATE 23505. We accept any error
		// message that contains the canonical phrase to keep the assertion
		// driver-agnostic.
		if !strings.Contains(err.Error(), "duplicate") &&
			!strings.Contains(err.Error(), "23505") {
			t.Fatalf("dup insert: want duplicate-key error, got %v", err)
		}
	})

	t.Run("neighbour isolation: A's puts don't leak into B", func(t *testing.T) {
		// Put one row on B with the same skill_id 1001 used on A — must NOT
		// collide; PK is composite on (char_id, abnormal_id).
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putabnormalstatus",
			cidPutAbnormalB, int(1001), int16(7), int16(3),
			int(11111), int(22222), int(33333), int(44444),
			int(100), int(200), int(300), int(400),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B insert: got %d, want 1", affected)
		}

		// A still has 3 rows; B has 1.
		var cntA, cntB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id = $1`,
			cidPutAbnormalA).Scan(&cntA); err != nil {
			t.Fatalf("count A: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id = $1`,
			cidPutAbnormalB).Scan(&cntB); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if cntA != 3 || cntB != 1 {
			t.Fatalf("isolation: A=%d (want 3) B=%d (want 1)", cntA, cntB)
		}

		// A's skill 1001 row still has lvl=5 (not B's lvl=7).
		var lvl int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT skill_level FROM user_abnormal_status
			  WHERE char_id = $1 AND skill_id = 1001`, cidPutAbnormalA).Scan(&lvl); err != nil {
			t.Fatalf("verify A intact: %v", err)
		}
		if lvl != 5 {
			t.Fatalf("A leaked from B: lvl=%d, want 5", lvl)
		}
	})

	t.Run("missing user_data: PutAbnormalStatus still succeeds (no FK)", func(t *testing.T) {
		// Bug-for-bug: NCSoft user_abnormal_status is freestanding — no FK
		// enforced on char_id. An insert for a non-existent char succeeds.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putabnormalstatus",
			cidPutAbnormalMissing, int(2222), int16(1), int16(0),
			int(5000), int(0), int(0), int(0),
			int(0), int(0), int(0), int(0),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 1 {
			t.Fatalf("missing affected: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id = $1`,
			cidPutAbnormalMissing).Scan(&cnt); err != nil {
			t.Fatalf("count missing: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("missing cnt: got %d, want 1", cnt)
		}
	})
}
