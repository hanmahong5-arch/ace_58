// Package database — integration test for the char_exps_reward SP pair
// (00252 SetCharEXPS_RewardTime / 00253 SetCharEXPS_RewardNum).
//
// Domain: NCSoft EXPS = Experience Points System — daily login-reward
// stream tracked on user_data_ext via two columns:
//   - exps_login_reward_time  : epoch-seconds of last login-reward stamp
//   - exps_npckill_reward_num : kills since last login (0 on every login)
//
// Test matrix:
//   - SetCharEXPS_RewardTime on missing user_data_ext row → INSERT branch,
//     row appears with (reward_time, 0) and other columns at defaults
//   - SetCharEXPS_RewardTime on existing row → UPDATE branch, time written,
//     kill-num is RESET TO 0 (NCSoft pin: every login wipes the counter)
//   - SetCharEXPS_RewardNum increments kill-num by exactly 1 (no clamp)
//   - SetCharEXPS_RewardNum on row absent before login → silent no-op,
//     returns 0 (NCSoft pin: kill before login is lost, not auto-created)
//   - Multiple RewardNum calls accumulate; subsequent RewardTime resets
//   - Cross-char isolation: bumping one char's counter does not affect
//     a neighbour's user_data_ext row
//
// char_id band: 9_610_081..9_610_099 (high half of batch 23 band — keeps
// hermetic vs the pvp_env entity-id band 9_610_001..99 which lives in a
// different table but whose numbers happen to overlap).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidExpsInsert     = 9610081 // first call — INSERT branch
	cidExpsUpdate     = 9610082 // covers INSERT then UPDATE branch
	cidExpsKillOnly   = 9610083 // RewardNum without prior RewardTime
	cidExpsAccum      = 9610084 // multiple kill increments
	cidExpsResetCheck = 9610085 // login resets accumulated counter
	cidExpsNeighbour  = 9610086 // neighbour, must not be touched
)

func charExpsRewardCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data_ext WHERE char_id BETWEEN 9610081 AND 9610099`); err != nil {
		t.Fatalf("charExpsRewardCleanup: %v", err)
	}
}

func TestCharExpsReward(t *testing.T) {
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

	charExpsRewardCleanup(t, ctx, pool)
	t.Cleanup(func() { charExpsRewardCleanup(t, context.Background(), pool) })

	t.Run("set reward time on missing row inserts with kill-num=0", func(t *testing.T) {
		// First call to RewardTime for this char_id — must INSERT.
		const t1 = int(1700001000) // arbitrary epoch
		if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardtime",
			cidExpsInsert, t1); err != nil {
			t.Fatalf("CallSPExec time: %v", err)
		}
		var loginTime, killNum int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT exps_login_reward_time, exps_npckill_reward_num
			   FROM user_data_ext WHERE char_id = $1`,
			cidExpsInsert).Scan(&loginTime, &killNum); err != nil {
			t.Fatalf("verify insert: %v", err)
		}
		if loginTime != t1 {
			t.Fatalf("insert time: got %d, want %d", loginTime, t1)
		}
		if killNum != 0 {
			t.Fatalf("insert kill-num: got %d, want 0 (NCSoft pin)", killNum)
		}
	})

	t.Run("set reward time on existing row updates and resets kill-num", func(t *testing.T) {
		// Seed via INSERT branch.
		if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardtime",
			cidExpsUpdate, int(1700000000)); err != nil {
			t.Fatalf("seed time: %v", err)
		}
		// Bump kill-num several times so the reset is observable.
		for i := 0; i < 5; i++ {
			if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardnum",
				cidExpsUpdate); err != nil {
				t.Fatalf("bump %d: %v", i, err)
			}
		}
		// Sanity: counter should be 5 just before the next RewardTime.
		var pre int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT exps_npckill_reward_num FROM user_data_ext WHERE char_id = $1`,
			cidExpsUpdate).Scan(&pre); err != nil {
			t.Fatalf("pre-reset count: %v", err)
		}
		if pre != 5 {
			t.Fatalf("pre-reset count: got %d, want 5", pre)
		}
		// Second RewardTime — UPDATE branch — must reset kill-num to 0
		// while writing the new login time.
		const t2 = int(1700009999)
		if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardtime",
			cidExpsUpdate, t2); err != nil {
			t.Fatalf("CallSPExec time #2: %v", err)
		}
		var loginTime, killNum int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT exps_login_reward_time, exps_npckill_reward_num
			   FROM user_data_ext WHERE char_id = $1`,
			cidExpsUpdate).Scan(&loginTime, &killNum); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if loginTime != t2 {
			t.Fatalf("update time: got %d, want %d", loginTime, t2)
		}
		if killNum != 0 {
			t.Fatalf("update kill-num: got %d, want 0 (login reset pin)", killNum)
		}
		// Row count must remain 1 (no duplicate from UPDATE branch).
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data_ext WHERE char_id = $1`,
			cidExpsUpdate).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("upsert produced %d rows, want 1", n)
		}
	})

	t.Run("set reward num before any login is silent no-op", func(t *testing.T) {
		// No prior RewardTime — user_data_ext row absent.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setcharexps_rewardnum",
			cidExpsKillOnly).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow num-noop: %v", err)
		}
		if affected != 0 {
			t.Fatalf("kill-before-login: got %d, want 0 (NCSoft pin)", affected)
		}
		// And the row must NOT have been auto-created.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data_ext WHERE char_id = $1`,
			cidExpsKillOnly).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("auto-create leak: got %d rows, want 0", n)
		}
	})

	t.Run("set reward num accumulates by exactly +1 per call", func(t *testing.T) {
		// Establish row via RewardTime.
		if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardtime",
			cidExpsAccum, int(1700100000)); err != nil {
			t.Fatalf("seed time: %v", err)
		}
		// Bump 7 times — counter must end at exactly 7.
		const bumps = 7
		for i := 0; i < bumps; i++ {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_setcharexps_rewardnum",
				cidExpsAccum).Scan(&affected); err != nil {
				t.Fatalf("bump %d: %v", i, err)
			}
			if affected != 1 {
				t.Fatalf("bump %d affected: got %d, want 1", i, affected)
			}
		}
		var killNum int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT exps_npckill_reward_num FROM user_data_ext WHERE char_id = $1`,
			cidExpsAccum).Scan(&killNum); err != nil {
			t.Fatalf("verify counter: %v", err)
		}
		if killNum != bumps {
			t.Fatalf("accumulated counter: got %d, want %d", killNum, bumps)
		}
	})

	t.Run("cross-char isolation: bumping one does not affect neighbour", func(t *testing.T) {
		// Seed two rows.
		if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardtime",
			cidExpsResetCheck, int(1700200000)); err != nil {
			t.Fatalf("seed reset: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardtime",
			cidExpsNeighbour, int(1700200000)); err != nil {
			t.Fatalf("seed neighbour: %v", err)
		}
		// Bump only the first char.
		for i := 0; i < 3; i++ {
			if err := pool.CallSPExec(ctx, "aion_setcharexps_rewardnum",
				cidExpsResetCheck); err != nil {
				t.Fatalf("bump check: %v", err)
			}
		}
		// Verify first char counter == 3.
		var checkNum int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT exps_npckill_reward_num FROM user_data_ext WHERE char_id = $1`,
			cidExpsResetCheck).Scan(&checkNum); err != nil {
			t.Fatalf("verify check: %v", err)
		}
		if checkNum != 3 {
			t.Fatalf("check counter: got %d, want 3", checkNum)
		}
		// Neighbour counter must remain 0.
		var neighNum int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT exps_npckill_reward_num FROM user_data_ext WHERE char_id = $1`,
			cidExpsNeighbour).Scan(&neighNum); err != nil {
			t.Fatalf("verify neighbour: %v", err)
		}
		if neighNum != 0 {
			t.Fatalf("neighbour leak: got %d, want 0", neighNum)
		}
	})
}
