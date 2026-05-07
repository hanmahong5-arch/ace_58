// Package database — integration test for aion_PutCharInGameBlockPunishInfo
// (record a new in-game punishment / mute / kick session).
//
// Two-statement body:
//   1. UPDATE user_punishment SET status=1, cancel_date=NOW()
//        WHERE (account_id, char_id, punish_code) match AND status=0
//   2. INSERT INTO user_punishment(...)  with status=0 (active)
//
// Test matrix:
//   - first call: 0 prior rows → 1 active row with end_date = NOW()+remain_min
//   - second call: 1 prior active row → that row becomes status=1 (cancelled)
//                  with cancel_date set, and a NEW active row appears
//   - second call with different punish_code: prior row stays ACTIVE (filter
//     scoped per punish_code; bug-for-bug pin)
//   - negative remain_minute: end_date < start_date (NCSoft "instantly expired")
//   - punish_reason TEXT round-trips with non-ASCII payload
//   - distinct chars on the same account coexist independently
//
// char_id band: 9_600_080..9_600_099 (batch 22 — punishment sub-band).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPunishA       = 9600080 // primary char for cancel-then-insert flow
	cidPunishB       = 9600081 // distinct char on same account
	cidPunishMulti   = 9600082 // multi-code coexistence
	cidPunishNeg     = 9600083 // negative remain_min sentinel
	cidPunishUnicode = 9600084 // non-ASCII reason round-trip

	accPunishA       = 5500080
	punishCodeMute   = 1
	punishCodeKick   = 2
)

func putPunishCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_punishment WHERE char_id BETWEEN 9600080 AND 9600099`); err != nil {
		t.Fatalf("putPunishCleanup: %v", err)
	}
}

func TestPutCharInGameBlockPunishInfo(t *testing.T) {
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

	putPunishCleanup(t, ctx, pool)
	t.Cleanup(func() { putPunishCleanup(t, context.Background(), pool) })

	t.Run("first call: zero priors → one active row, end_date in future", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishA, punishCodeMute, int(60), "test mute"); err != nil {
			t.Fatalf("first put: %v", err)
		}

		var (
			n            int
			status       int16
			remain       int32
			reason       string
			endAfterStart bool
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment WHERE char_id=$1`,
			cidPunishA).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("first row count: got %d, want 1", n)
		}

		if err := pool.Inner().QueryRow(ctx,
			`SELECT status, remain_minute, punish_reason,
			        (end_date > start_date)
			   FROM user_punishment WHERE char_id=$1`,
			cidPunishA).Scan(&status, &remain, &reason, &endAfterStart); err != nil {
			t.Fatalf("verify first: %v", err)
		}
		if status != 0 || remain != 60 || reason != "test mute" || !endAfterStart {
			t.Fatalf("first row: status=%d remain=%d reason=%q endAfter=%v, want 0/60/test mute/true",
				status, remain, reason, endAfterStart)
		}
	})

	t.Run("second call same code: prior row cancelled (status=1), new active inserted", func(t *testing.T) {
		// (cidPunishA, mute) already has 1 active row from the previous sub-test.
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishA, punishCodeMute, int(120), "second mute"); err != nil {
			t.Fatalf("second put: %v", err)
		}

		// Row count for (acc, char, code) is now 2: one cancelled, one active.
		var (
			nCancelled int
			nActive    int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment
			  WHERE account_id=$1 AND char_id=$2 AND punish_code=$3 AND status=1`,
			accPunishA, cidPunishA, punishCodeMute).Scan(&nCancelled); err != nil {
			t.Fatalf("cancelled count: %v", err)
		}
		if nCancelled != 1 {
			t.Fatalf("cancelled rows: got %d, want 1", nCancelled)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment
			  WHERE account_id=$1 AND char_id=$2 AND punish_code=$3 AND status=0`,
			accPunishA, cidPunishA, punishCodeMute).Scan(&nActive); err != nil {
			t.Fatalf("active count: %v", err)
		}
		if nActive != 1 {
			t.Fatalf("active rows: got %d, want 1", nActive)
		}

		// The cancelled row MUST have cancel_date set (NOT NULL).
		var cancelDateNotNull bool
		if err := pool.Inner().QueryRow(ctx,
			`SELECT (cancel_date IS NOT NULL)
			   FROM user_punishment
			  WHERE account_id=$1 AND char_id=$2 AND punish_code=$3 AND status=1`,
			accPunishA, cidPunishA, punishCodeMute).Scan(&cancelDateNotNull); err != nil {
			t.Fatalf("cancel_date check: %v", err)
		}
		if !cancelDateNotNull {
			t.Fatal("cancelled row's cancel_date is NULL, want non-NULL")
		}
	})

	t.Run("second call DIFFERENT punish_code: prior row stays active (per-code scope)", func(t *testing.T) {
		// Seed an active mute on cidPunishMulti.
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishMulti, punishCodeMute, int(30), "mute"); err != nil {
			t.Fatalf("seed mute: %v", err)
		}
		// Now apply a kick — different punish_code, so mute MUST stay active.
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishMulti, punishCodeKick, int(15), "kick"); err != nil {
			t.Fatalf("kick: %v", err)
		}

		var nMuteActive int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment
			  WHERE char_id=$1 AND punish_code=$2 AND status=0`,
			cidPunishMulti, punishCodeMute).Scan(&nMuteActive); err != nil {
			t.Fatalf("active-mute count: %v", err)
		}
		if nMuteActive != 1 {
			t.Fatalf("mute survival: got %d active, want 1 (per-code scope)", nMuteActive)
		}

		var nKickActive int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment
			  WHERE char_id=$1 AND punish_code=$2 AND status=0`,
			cidPunishMulti, punishCodeKick).Scan(&nKickActive); err != nil {
			t.Fatalf("active-kick count: %v", err)
		}
		if nKickActive != 1 {
			t.Fatalf("kick active: got %d, want 1", nKickActive)
		}
	})

	t.Run("negative remain_minute: end_date < start_date (NCSoft sentinel)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishNeg, punishCodeMute, int(-5), "expired"); err != nil {
			t.Fatalf("negative remain: %v", err)
		}
		var endBeforeStart bool
		if err := pool.Inner().QueryRow(ctx,
			`SELECT (end_date < start_date) FROM user_punishment
			  WHERE char_id=$1`,
			cidPunishNeg).Scan(&endBeforeStart); err != nil {
			t.Fatalf("verify neg: %v", err)
		}
		if !endBeforeStart {
			t.Fatal("negative remain_minute: end_date NOT before start_date")
		}
	})

	t.Run("non-ASCII punish_reason round-trips", func(t *testing.T) {
		reason := "PvP 中文 てすと" // mixed CJK
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishUnicode, punishCodeMute, int(10), reason); err != nil {
			t.Fatalf("unicode: %v", err)
		}
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT punish_reason FROM user_punishment WHERE char_id=$1`,
			cidPunishUnicode).Scan(&got); err != nil {
			t.Fatalf("verify unicode: %v", err)
		}
		if got != reason {
			t.Fatalf("unicode round-trip: got %q, want %q", got, reason)
		}
	})

	t.Run("distinct chars on same account coexist", func(t *testing.T) {
		// cidPunishA already has rows. Apply a mute to cidPunishB.
		if err := pool.CallSPExec(ctx, "aion_putcharingameblockpunishinfo",
			accPunishA, cidPunishB, punishCodeMute, int(45), "B mute"); err != nil {
			t.Fatalf("char B: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment
			  WHERE account_id=$1 AND char_id=$2 AND status=0`,
			accPunishA, cidPunishB).Scan(&n); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if n != 1 {
			t.Fatalf("B active: got %d, want 1", n)
		}

		// cidPunishA's prior active mute (from sub-test 2) MUST still be active.
		var nA int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_punishment
			  WHERE account_id=$1 AND char_id=$2 AND punish_code=$3 AND status=0`,
			accPunishA, cidPunishA, punishCodeMute).Scan(&nA); err != nil {
			t.Fatalf("count A active: %v", err)
		}
		if nA != 1 {
			t.Fatalf("A active interference: got %d, want 1 (B insertion must not cancel A)", nA)
		}
	})
}
