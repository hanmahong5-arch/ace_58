// Package database — Char 生命周期清理 batch 27 integration tests for the 5
// re-batched cleanup SPs (00276-00280).
//
// Goal: pin NCSoft bug-for-bug semantics on the cleanup cascade so future
// schema/SP changes don't drift the contract. Each sub-test covers:
//
//   - happy path           — wipe with seeded rows
//   - missing-row no-op    — wipe with no rows present
//   - multi-row fan-out    — wipe a char with multiple rows in one shot
//   - idempotent re-invoke — second call is a no-op (NCSoft does not error)
//
// SPs covered (5):
//
//   00276 aion_ClearCharDeleteTime           — UPDATE delete_date=0
//   00277 aion_DeleteAllAbnormalStatus       — DELETE buffs by char
//   00278 aion_DeleteAllFactionFriendship    — DELETE faction reps by char
//   00279 aion_DeleteAllPromotionCoolTime    — DELETE promo cooltimes by promo_id (NOT char_id)
//   00280 aion_DeleteAllSkill                — DELETE skills by char
//
// Cleanup band: char_id 9_710_001..9_710_099 (batch 27 reserve, distinct from
// Round 10's 9_010_000 band so the two test files don't collide).
//
// Run (skip-if-no-PG default; opt-in via AION_TEST_PG_* env tuple):
//
//	cd server/src
//	go test -count=1 -run TestSPCharLifecycleCleanup -v ./internal/database
package database

import (
	"context"
	"testing"
	"time"
)

// charCleanupBatch27Cleanup wipes batch-27 fixtures across every table the
// SPs touch. Run pre+post each test invocation so reruns are deterministic.
//
// promotion_id band 27_001..27_099 is reserved for the promo SP test —
// also wiped here so reruns don't carry promo rows from a prior failure.
func charCleanupBatch27Cleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	stmts := []string{
		`DELETE FROM user_promotion_cooltime    WHERE char_id BETWEEN 9710001 AND 9710099`,
		`DELETE FROM user_promotion_cooltime    WHERE promotion_id BETWEEN 27001 AND 27099`,
		`DELETE FROM user_faction_friendship    WHERE char_id BETWEEN 9710001 AND 9710099`,
		`DELETE FROM user_abnormal_status       WHERE char_id BETWEEN 9710001 AND 9710099`,
		`DELETE FROM user_skill                 WHERE char_id BETWEEN 9710001 AND 9710099`,
		`DELETE FROM user_data                  WHERE char_id BETWEEN 9710001 AND 9710099`,
	}
	for _, stmt := range stmts {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("charCleanupBatch27Cleanup %q: %v", stmt, err)
		}
	}
}

// setupCharCleanupBatch27 boots PG, runs migrations, opens a pool, and
// registers cleanup. Mirror of setupRound10 with a different cleanup band.
func setupCharCleanupBatch27(t *testing.T) (*Pool, context.Context, context.CancelFunc) {
	t.Helper()
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	if err := Migrate(ctx, dsn); err != nil {
		cancel()
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		cancel()
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	charCleanupBatch27Cleanup(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		charCleanupBatch27Cleanup(t, bg, pool)
	})
	return pool, ctx, cancel
}

// seedCleanupCharRow inserts a minimal user_data row so SPs that depend on
// the char existing (00276 ClearCharDeleteTime) have something to update.
// Skips for SPs that operate on tables without an FK to user_data
// (00277/00278/00279/00280 all hard-DELETE without referential check).
func seedCleanupCharRow(t *testing.T, ctx context.Context, p *Pool, charID, accountID int, name string) {
	t.Helper()
	_, err := p.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, user_id, name, account_id, account_name,
		                       race, class, lev, world)
		 VALUES ($1, $2, $2, $3, 'b27_acct', 1, 1, 50, 210050000)`,
		charID, name, accountID,
	)
	if err != nil {
		t.Fatalf("seedCleanupCharRow(%d): %v", charID, err)
	}
}

// TestSPCharLifecycleCleanup — 5 sub-tests, one per SP, each covering happy
// path + 2-3 NCSoft bug-for-bug edge cases.
func TestSPCharLifecycleCleanup(t *testing.T) {
	pool, ctx, cancel := setupCharCleanupBatch27(t)
	defer cancel()

	// =====================================================================
	// 00276 aion_ClearCharDeleteTime
	// =====================================================================
	t.Run("00276 ClearCharDeleteTime zeroes delete_date and bumps change_info_time", func(t *testing.T) {
		const cid = 9710001
		seedCleanupCharRow(t, ctx, pool, cid, 9710001, "b27_clr")
		// Mark the char for delete first (sister SP 00006 SetCharDeleteTime).
		const futureDelete = 1900000000 // year 2030, well in the future
		if err := pool.CallSPExec(ctx, "aion_setchardeletetime", cid, futureDelete); err != nil {
			t.Fatalf("setdel: %v", err)
		}

		// Capture pre-clear change_info_time so we can prove it gets bumped.
		var preCIT int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT change_info_time FROM user_data WHERE char_id=$1`, cid).Scan(&preCIT)

		// Sleep 1 second so the unix-second-resolution change_info_time
		// is guaranteed to differ. NCSoft GetUnixtimeWithUTCAdjust returns
		// integer seconds — sub-second writes would alias.
		time.Sleep(1100 * time.Millisecond)

		if err := pool.CallSPExec(ctx, "aion_clearchardeletetime", cid); err != nil {
			t.Fatalf("clear: %v", err)
		}

		var dd, postCIT int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT delete_date, change_info_time FROM user_data WHERE char_id=$1`, cid).
			Scan(&dd, &postCIT)
		if dd != 0 {
			t.Fatalf("delete_date not cleared: got %d", dd)
		}
		if postCIT <= preCIT {
			t.Fatalf("change_info_time not bumped: pre=%d post=%d", preCIT, postCIT)
		}

		// Edge: re-invoke on already-cleared char is no-op (no error, dd
		// stays 0). NCSoft does not RAISERROR.
		if err := pool.CallSPExec(ctx, "aion_clearchardeletetime", cid); err != nil {
			t.Fatalf("idempotent clear: %v", err)
		}

		// Edge: invoke on non-existent char_id — UPDATE matches 0 rows,
		// no error. NCSoft pin.
		if err := pool.CallSPExec(ctx, "aion_clearchardeletetime", 9710999); err != nil {
			t.Fatalf("clear missing char: %v", err)
		}
	})

	// =====================================================================
	// 00277 aion_DeleteAllAbnormalStatus
	// =====================================================================
	t.Run("00277 DeleteAllAbnormalStatus wipes buff/debuff fan-out for one char", func(t *testing.T) {
		const cid = 9710002
		// Seed 4 different buffs (multi-row fan-out test).  00210 added
		// UNIQUE(char_id, skill_id), and 00209's ALTER added skill_id with
		// DEFAULT 0 — so we must set distinct skill_ids per row, not just
		// abnormal_ids.  The legacy R7 PK (char_id, abnormal_id) still keeps
		// rows distinguishable; skill_id mirrors abnormal_id for clarity.
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_abnormal_status(char_id, abnormal_id, skill_id, remain_time_ms) VALUES
			 ($1, 1001, 1001, 30000), ($1, 1002, 1002, 60000),
			 ($1, 1003, 1003, 5000),  ($1, 1004, 1004, 1)`, cid)
		if err != nil {
			t.Fatalf("seed buffs: %v", err)
		}

		if err := pool.CallSPExec(ctx, "aion_deleteallabnormalstatus", cid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id=$1`, cid).Scan(&n)
		if n != 0 {
			t.Fatalf("buffs not wiped: count=%d", n)
		}

		// Edge: scope check — wiping cid must not touch a sibling char's buffs.
		const otherCid = 9710003
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_abnormal_status(char_id, abnormal_id, remain_time_ms)
			 VALUES ($1, 2001, 1000)`, otherCid)
		if err := pool.CallSPExec(ctx, "aion_deleteallabnormalstatus", cid); err != nil {
			t.Fatalf("rerun on cleaned char: %v", err)
		}
		var nOther int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id=$1`, otherCid).Scan(&nOther)
		if nOther != 1 {
			t.Fatalf("scope leak: other char_id %d count=%d (want 1)", otherCid, nOther)
		}

		// Edge: invoke on char with no rows — DELETE 0 rows, no error.
		if err := pool.CallSPExec(ctx, "aion_deleteallabnormalstatus", 9710999); err != nil {
			t.Fatalf("delete empty: %v", err)
		}
	})

	// =====================================================================
	// 00278 aion_DeleteAllFactionFriendship
	// =====================================================================
	t.Run("00278 DeleteAllFactionFriendship wipes every faction row for one char", func(t *testing.T) {
		const cid = 9710004
		// Seed 3 faction rows (one char can join multiple sub-factions).
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_faction_friendship(char_id, faction_id, friendship, jointime) VALUES
			 ($1, 101, 5000, 1700000000),
			 ($1, 102, 3000, 1700000100),
			 ($1, 103,  500, 1700000200)`, cid)
		if err != nil {
			t.Fatalf("seed faction: %v", err)
		}

		if err := pool.CallSPExec(ctx, "aion_deleteallfactionfriendship", cid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship WHERE char_id=$1`, cid).Scan(&n)
		if n != 0 {
			t.Fatalf("faction rows not wiped: count=%d", n)
		}

		// Edge: scope — sibling char's faction rows must remain.
		const otherCid = 9710005
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_faction_friendship(char_id, faction_id, friendship, jointime)
			 VALUES ($1, 201, 100, 1700000300)`, otherCid)
		if err := pool.CallSPExec(ctx, "aion_deleteallfactionfriendship", cid); err != nil {
			t.Fatalf("rerun on cleaned char: %v", err)
		}
		var nOther int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship WHERE char_id=$1`, otherCid).Scan(&nOther)
		if nOther != 1 {
			t.Fatalf("scope leak: other char_id %d count=%d (want 1)", otherCid, nOther)
		}

		// Edge: empty char — no rows, no error.
		if err := pool.CallSPExec(ctx, "aion_deleteallfactionfriendship", 9710999); err != nil {
			t.Fatalf("delete empty: %v", err)
		}

		// Edge: distinct from 00086 (DeleteFactionFriendship) — verify
		// **all** 5 factionquest_* tracking columns are gone, not just
		// jointime soft-zeroed (the 00086 path).
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_faction_friendship(char_id, faction_id, friendship, jointime,
			                                     factionquest_curid, factionquest_curstate,
			                                     factionquest_finishedcount)
			 VALUES ($1, 301, 9999, 1700000400, 555, 1, 7)`, cid)
		if err := pool.CallSPExec(ctx, "aion_deleteallfactionfriendship", cid); err != nil {
			t.Fatalf("hard-delete with quest cols: %v", err)
		}
		var hasRow int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship WHERE char_id=$1`, cid).Scan(&hasRow)
		if hasRow != 0 {
			t.Fatalf("hard-delete miss: count=%d (want 0; this SP is hard-delete, not soft like 00086)", hasRow)
		}
	})

	// =====================================================================
	// 00279 aion_DeleteAllPromotionCoolTime  (keyed on promo_id, NOT char_id)
	// =====================================================================
	t.Run("00279 DeleteAllPromotionCoolTime wipes a server-wide promo across all chars", func(t *testing.T) {
		const (
			cid1     = 9710006
			cid2     = 9710007
			cid3     = 9710008
			promo1   = int16(27001) // the promo we'll wipe
			promo2   = int16(27002) // unrelated promo, must survive
		)
		// 3 chars, each holds rows in promo1 + promo2.
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_promotion_cooltime(char_id, promotion_id) VALUES
			 ($1, $4), ($1, $5),
			 ($2, $4), ($2, $5),
			 ($3, $4)`,
			cid1, cid2, cid3, promo1, promo2)
		if err != nil {
			t.Fatalf("seed promos: %v", err)
		}

		// Wipe promo1 — should affect 3 rows (one per char that held it).
		var affected int
		err = pool.CallSPRow(ctx, "aion_deleteallpromotioncooltime", promo1).Scan(&affected)
		if err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 3 {
			t.Fatalf("affected: got %d, want 3 (3 chars held promo1)", affected)
		}

		// promo1 → 0 rows.
		var nP1 int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime WHERE promotion_id=$1`, promo1).Scan(&nP1)
		if nP1 != 0 {
			t.Fatalf("promo1 not wiped: count=%d", nP1)
		}

		// promo2 → 2 rows (cid1, cid2 still hold it; cid3 never did).
		var nP2 int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_promotion_cooltime WHERE promotion_id=$1`, promo2).Scan(&nP2)
		if nP2 != 2 {
			t.Fatalf("promo2 scope leak: count=%d (want 2)", nP2)
		}

		// Edge: idempotent re-wipe — already empty promo, returns 0.
		var affectedRerun int
		err = pool.CallSPRow(ctx, "aion_deleteallpromotioncooltime", promo1).Scan(&affectedRerun)
		if err != nil {
			t.Fatalf("idempotent rerun: %v", err)
		}
		if affectedRerun != 0 {
			t.Fatalf("idempotent rerun affected=%d, want 0", affectedRerun)
		}

		// Edge: never-existed promo_id, returns 0.
		var affectedNever int
		err = pool.CallSPRow(ctx, "aion_deleteallpromotioncooltime", int16(27099)).Scan(&affectedNever)
		if err != nil {
			t.Fatalf("never-existed promo: %v", err)
		}
		if affectedNever != 0 {
			t.Fatalf("never-existed promo affected=%d, want 0", affectedNever)
		}
	})

	// =====================================================================
	// 00280 aion_DeleteAllSkill
	// =====================================================================
	t.Run("00280 DeleteAllSkill wipes every learned skill row for one char", func(t *testing.T) {
		const cid = 9710009
		// Seed 5 skills, mixing skill_data1/2 (XP/charge counters) to prove
		// the row-level wipe takes those out too.
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_skill(char_id, skill_id, skill_data1, skill_data2) VALUES
			 ($1, 100, 0, 0),
			 ($1, 101, 50, 0),
			 ($1, 102, 0, 100),
			 ($1, 103, 999, 999),
			 ($1, 104, 1, 1)`, cid)
		if err != nil {
			t.Fatalf("seed skills: %v", err)
		}

		if err := pool.CallSPExec(ctx, "aion_deleteallskill", cid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_skill WHERE char_id=$1`, cid).Scan(&n)
		if n != 0 {
			t.Fatalf("skills not wiped: count=%d", n)
		}

		// Edge: scope — sibling char's skills must remain.
		const otherCid = 9710010
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_skill(char_id, skill_id) VALUES ($1, 200)`, otherCid)
		if err := pool.CallSPExec(ctx, "aion_deleteallskill", cid); err != nil {
			t.Fatalf("rerun on cleaned char: %v", err)
		}
		var nOther int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_skill WHERE char_id=$1`, otherCid).Scan(&nOther)
		if nOther != 1 {
			t.Fatalf("scope leak: other char_id %d count=%d (want 1)", otherCid, nOther)
		}

		// Edge: idempotent re-invoke on the already-cleaned char.
		if err := pool.CallSPExec(ctx, "aion_deleteallskill", cid); err != nil {
			t.Fatalf("idempotent re-invoke: %v", err)
		}

		// Edge: invoke on never-existed char — DELETE 0 rows, no error.
		if err := pool.CallSPExec(ctx, "aion_deleteallskill", 9710999); err != nil {
			t.Fatalf("delete empty: %v", err)
		}
	})
}
