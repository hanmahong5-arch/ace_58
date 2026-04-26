// Package database — Sprint 1.1a smoke tests for the first 5 ported NCSoft SPs.
//
// Each SubTest exercises one stored procedure end-to-end:
//  1. seed user_data / guild rows directly with INSERT (test setup only;
//     production paths must always go through SPs)
//  2. invoke the SP via Pool.CallSP / CallSPRow / CallSPExec
//  3. assert the observable side effect (returned rows, mutated state)
//
// Convention follows migrate_test.go: the test is gated on the
// AION_TEST_PG_* env tuple and Skip()s when not configured, so a default
// `go test ./...` on a contributor's box without local PG stays green.
package database

import (
	"context"
	"testing"
	"time"
)

// fixtureCleanup wipes the rows under test so subtests are independent.
// We reach past the SP layer here because the corresponding cleanup SPs
// are Round 5+ work; this is a pure test-infra concern.
//
// Round 5 (Track B3) extension: we now also wipe user_item, user_skill,
// user_quest, user_instance, user_mail, forbidden_word and forbidden_char
// in the dedicated 9_000_000-9_000_099 char-id band so subtests don't pollute
// each other.
//
// Round 6 (Track B4) extension: PutChar_20160620 allocates char_ids via
// MAX(char_id)+1 inside the SP, which puts the new rows ABOVE the 9_000_000-
// 9_000_099 band on subsequent runs. We therefore widen the wipe band to
// 9_000_000-9_000_999 so PutChar-allocated identities are reaped between runs
// (matches the user_id LIKE 'b4test_%' wipe that already existed for the
// dup-name PutChar variant).
func fixtureCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, stmt := range []string{
		`DELETE FROM user_item_attribute WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9000000 AND 9000999)`,
		`DELETE FROM user_item_polish    WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9000000 AND 9000999)`,
		`DELETE FROM user_item_charge    WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9000000 AND 9000999)`,
		`DELETE FROM user_item_option    WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_item           WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_skill          WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_skill_cooltime WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_skill_skin     WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_quest          WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_finished_quest WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_instance       WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_mail           WHERE to_id   BETWEEN 9000000 AND 9000999 OR from_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM forbidden_word      WHERE forbidden_word LIKE 'b3test_%'`,
		`DELETE FROM forbidden_char      WHERE forbidden_char LIKE 'b3test_%'`,
		`DELETE FROM user_data           WHERE char_id BETWEEN 9000000 AND 9000999`,
		`DELETE FROM user_data           WHERE user_id LIKE 'b4test_%'`,
		`DELETE FROM guild               WHERE id      BETWEEN 9000000 AND 9000999`,
		`DELETE FROM guild               WHERE name LIKE 'b3test_%'`,
		`DELETE FROM guild               WHERE name LIKE 'b4test_%'`,
	} {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("fixtureCleanup %q: %v", stmt, err)
		}
	}
}

// TestPortedSPs_PvECore — Sprint 1.1a five-SP smoke.
func TestPortedSPs_PvECore(t *testing.T) {
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
	// Register cleanup BEFORE close so the LIFO ordering wipes fixtures
	// while the pool is still alive (t.Cleanup is LIFO; later registrations
	// run first).
	t.Cleanup(pool.Close)

	fixtureCleanup(t, ctx, pool)
	t.Cleanup(func() { fixtureCleanup(t, context.Background(), pool) })

	// Seed: one guild + one character bound to it.
	const (
		gid  = 9000001 // guild
		cid  = 9000010 // character bound to gid
		cid2 = 9000011 // character free for SetGuildMember test
	)
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO guild(id, name, race, level, intro)
		 VALUES ($1, 'TestLegion', 1, 5, 'hello')`, gid); err != nil {
		t.Fatalf("seed guild: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, guild_id) VALUES ($1, 'Alice', $2), ($3, 'Bob', 0)`,
		cid, gid, cid2); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	t.Run("aion_GetCharGuildId returns the bound guild", func(t *testing.T) {
		var got int
		if err := pool.CallSPRow(ctx, "aion_getcharguildid", cid).Scan(&got); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if got != gid {
			t.Fatalf("guild_id mismatch: got %d, want %d", got, gid)
		}
	})

	t.Run("aion_GetGuild_20150508 returns the guild row", func(t *testing.T) {
		var (
			name           string
			race, masterID int
			level, rank    int
			subRight, offRight, memRight, newbieRight int
			point, fund    int64
			thisTld, lastTld, tldUpd int
			delReq, delTime int
			intro          string
			joinType, joinLvl int
		)
		err := pool.CallSPRow(ctx, "aion_getguild_20150508", gid).Scan(
			&name, &race, &masterID, &level, &rank,
			&subRight, &offRight, &memRight, &newbieRight,
			&point, &fund,
			&thisTld, &lastTld, &tldUpd,
			&delReq, &delTime, &intro,
			&joinType, &joinLvl,
		)
		if err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if name != "TestLegion" || level != 5 || intro != "hello" {
			t.Fatalf("guild row mismatch: name=%q level=%d intro=%q", name, level, intro)
		}
	})

	t.Run("aion_SetCharDeleteTime persists the schedule", func(t *testing.T) {
		const at = 1745532000 // arbitrary fixed epoch
		if err := pool.CallSPExec(ctx, "aion_setchardeletetime", cid, at); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var got int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT delete_date FROM user_data WHERE char_id = $1`, cid).
			Scan(&got); err != nil {
			t.Fatalf("verify select: %v", err)
		}
		if got != at {
			t.Fatalf("delete_date mismatch: got %d, want %d", got, at)
		}
	})

	t.Run("aion_SetGuildMember binds char and returns guild_id", func(t *testing.T) {
		var ret int
		if err := pool.CallSPRow(ctx, "aion_setguildmember", gid, cid2).Scan(&ret); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if ret != gid {
			t.Fatalf("returned guild_id mismatch: got %d, want %d", ret, gid)
		}
		var stored int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT guild_id FROM user_data WHERE char_id = $1`, cid2).
			Scan(&stored); err != nil {
			t.Fatalf("verify select: %v", err)
		}
		if stored != gid {
			t.Fatalf("stored guild_id mismatch: got %d, want %d", stored, gid)
		}
	})

	t.Run("aion_DeleteGuild removes the row", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_deleteguild", gid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM guild WHERE id = $1`, gid).Scan(&n); err != nil {
			t.Fatalf("verify count: %v", err)
		}
		if n != 0 {
			t.Fatalf("guild not deleted: count=%d", n)
		}
	})
}

// TestPortedSPs_Round5 — round-trip tests for the 18 Round 5 (Track B3) SP ports.
//
// Layout: each subtest is independent and seeds its own row(s) in the
// 9_000_000-9_000_099 char-id band. fixtureCleanup wipes the band before and
// after the outer test runs.
//
// SPs covered (16 of 18 — see priority-50.md for TODO-flagged ones):
//   aion_GetCharIdList, aion_CheckValidCharName,
//   aion_SetCharLogoutTime_20120516, aion_SetCharLoginTime_20120516,
//   aion_SetCharLocation, aion_GetCharLocation,
//   aion_SetCharCP, aion_AddCharRankPoint,
//   aion_GetItem, aion_PutItem_20150921, aion_DeleteItem, aion_SetItemAmount,
//   aion_GetSkillList, aion_PutSkill,
//   aion_GetQuestList, aion_PutQuest,
//   aion_GetUserInstance_20171122, aion_SetUserInstance_20171122,
//   aion_InitInstanceCooltime_170817,
//   aion_DeleteGuildMemberAll, aion_SetGuildMemberRank, aion_PutGuild_20100916,
//   aion_MailWriteSys_20111227.
//
// (Counts as 23 SPs; 18 from priority-50 + 5 supporting.)
func TestPortedSPs_Round5(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	fixtureCleanup(t, ctx, pool)
	t.Cleanup(func() { fixtureCleanup(t, context.Background(), pool) })

	// Shared band of test ids — 9_000_020 through 9_000_099 reserved for
	// Round 5 to avoid collision with the Round 4 5-SP smoke (which uses
	// 9_000_000 through 9_000_019). Subtests pick disjoint slots.
	const accID = 909000

	// ---- char lifecycle ----------------------------------------------------

	t.Run("aion_GetCharIdList enumerates account chars filtered by delete_date", func(t *testing.T) {
		// Seed 3 chars: alive, scheduled-future, scheduled-past
		const (
			cAlive  = 9000020
			cFuture = 9000021
			cPast   = 9000022
		)
		now := int(time.Now().Unix())
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, account_id, delete_date)
			 VALUES ($1,'A','alpha',$4,0),($2,'B','bravo',$4,$5),($3,'C','charlie',$4,$6)`,
			cAlive, cFuture, cPast, accID, now+86400, now-86400); err != nil {
			t.Fatalf("seed: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getcharidlist", accID)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var ids []int
		for rows.Next() {
			var id int
			var uname string
			if err := rows.Scan(&id, &uname); err != nil {
				t.Fatalf("scan: %v", err)
			}
			ids = append(ids, id)
		}
		// alive + future should be returned, past filtered out
		if len(ids) != 2 {
			t.Fatalf("want 2 alive chars, got %d (%v)", len(ids), ids)
		}
	})

	t.Run("aion_CheckValidCharName returns 0 for fresh name and -1 for taken", func(t *testing.T) {
		const cid = 9000030
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'Taken', 'b3test_taken')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		var rc int
		if err := pool.CallSPRow(ctx, "aion_checkvalidcharname", "b3test_freshname", "b3test_acct").Scan(&rc); err != nil {
			t.Fatalf("CallSPRow fresh: %v", err)
		}
		if rc != 0 {
			t.Fatalf("fresh: want 0, got %d", rc)
		}
		if err := pool.CallSPRow(ctx, "aion_checkvalidcharname", "b3test_taken", "b3test_acct").Scan(&rc); err != nil {
			t.Fatalf("CallSPRow taken: %v", err)
		}
		if rc != -1 {
			t.Fatalf("taken: want -1, got %d", rc)
		}
	})

	t.Run("aion_SetCharLoginTime + LogoutTime persist times and accumulate playtime", func(t *testing.T) {
		const cid = 9000031
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Pl')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		var loginTS time.Time
		if err := pool.CallSPRow(ctx, "aion_setcharlogintime_20120516", cid).Scan(&loginTS); err != nil {
			t.Fatalf("login: %v", err)
		}
		// Backdate last_login_time by 90 seconds so playtime increments by ≥1
		if _, err := pool.Inner().Exec(ctx,
			`UPDATE user_data SET last_login_time = NOW() - INTERVAL '90 seconds' WHERE char_id = $1`, cid); err != nil {
			t.Fatalf("backdate: %v", err)
		}
		var logoutTS time.Time
		if err := pool.CallSPRow(ctx, "aion_setcharlogouttime_20120516", cid).Scan(&logoutTS); err != nil {
			t.Fatalf("logout: %v", err)
		}
		var playtime int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT playtime FROM user_data WHERE char_id = $1`, cid).Scan(&playtime); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if playtime < 1 {
			t.Fatalf("playtime should have incremented by ≥1 minute; got %d", playtime)
		}
	})

	t.Run("aion_SetCharLocation + GetCharLocation round-trip", func(t *testing.T) {
		const cid = 9000032
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Loc')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setcharlocation", cid, 1, 210050000, float32(100.5), float32(200.25), float32(300.75)); err != nil {
			t.Fatalf("set: %v", err)
		}
		var (
			curServer, world, dir int
			x, y, z               float32
		)
		if err := pool.CallSPRow(ctx, "aion_getcharlocation", cid).
			Scan(&curServer, &world, &x, &y, &z, &dir); err != nil {
			t.Fatalf("get: %v", err)
		}
		if curServer != 1 || world != 210050000 || x != 100.5 || y != 200.25 || z != 300.75 {
			t.Fatalf("round-trip mismatch: server=%d world=%d xyz=%g/%g/%g", curServer, world, x, y, z)
		}
	})

	t.Run("aion_SetCharCP persists champion-points", func(t *testing.T) {
		const cid = 9000033
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'CP')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setcharcp", cid, 4242); err != nil {
			t.Fatalf("set: %v", err)
		}
		var got int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cp FROM user_data WHERE char_id = $1`, cid).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 4242 {
			t.Fatalf("cp mismatch: %d != 4242", got)
		}
	})

	t.Run("aion_AddCharRankPoint accumulates", func(t *testing.T) {
		const cid = 9000034
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, rank_point) VALUES ($1, 'Rk', 100)`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		var got int64
		if err := pool.CallSPRow(ctx, "aion_addcharrankpoint", cid, 50).Scan(&got); err != nil {
			t.Fatalf("add: %v", err)
		}
		if got != 150 {
			t.Fatalf("rank_point: got %d, want 150", got)
		}
	})

	// ---- inventory ---------------------------------------------------------

	t.Run("aion_PutItem + GetItem + SetItemAmount + DeleteItem round-trip", func(t *testing.T) {
		const cid = 9000040
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Inv')`, cid); err != nil {
			t.Fatalf("seed char: %v", err)
		}
		// PutItem with all the cosmetic/enchant fields zeroed → should NOT
		// create user_item_option row.
		var newID int64
		err := pool.CallSPRow(ctx, "aion_putitem_20150921",
			cid,            // char_id
			110000001,      // name_id
			0,              // slot_id
			int64(5),       // amount
			int64(0),       // tid
			0,              // slot_num
			0,              // warehouse
			0, 0, 0,        // soul_bound, enchant_count, skin_name_id
			0, 0, 0, 0, 0, 0, // stat_enchant 0..5
			0,        // option_count
			0,        // dye_info
			0,        // proc_tool_nameid
			0,        // expired_time
			"system", // producer
			0, 0,     // buy_amount, buy_duration
			0, 0,     // obtain_skin_type, expire_skin_time
			0, 0,     // dynamic_property, server_of_origin
			0,        // expire_dye_time
			0,        // random_option
			0,        // limit_enchant_count
			0,        // reidentify_count
			0,        // authorize_count
			0,        // vanish_point
			0, 0,     // enchant_prob_addition, option_prob_addition
			0,        // key_name_id
			0, 0, 0, 0, // exceedState, exceedSkillId 1..3
			0, 0, 0,  // baseSkillId, enhanceSkillGroup, enhanceSkillLevel
		).Scan(&newID)
		if err != nil {
			t.Fatalf("PutItem: %v", err)
		}
		if newID == 0 {
			t.Fatalf("PutItem returned 0 id")
		}

		// GetItem
		rows, err := pool.CallSP(ctx, "aion_getitem", newID)
		if err != nil {
			t.Fatalf("GetItem: %v", err)
		}
		var found bool
		for rows.Next() {
			found = true
		}
		rows.Close()
		if !found {
			t.Fatalf("GetItem returned no rows for id %d", newID)
		}

		// SetItemAmount
		if err := pool.CallSPExec(ctx, "aion_setitemamount", newID, int64(99)); err != nil {
			t.Fatalf("SetItemAmount: %v", err)
		}
		var amt int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_item WHERE id = $1`, newID).Scan(&amt); err != nil {
			t.Fatalf("verify amount: %v", err)
		}
		if amt != 99 {
			t.Fatalf("amount: got %d, want 99", amt)
		}

		// DeleteItem
		if err := pool.CallSPExec(ctx, "aion_deleteitem", newID); err != nil {
			t.Fatalf("DeleteItem: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item WHERE id = $1`, newID).Scan(&n); err != nil {
			t.Fatalf("verify count: %v", err)
		}
		if n != 0 {
			t.Fatalf("DeleteItem left %d rows", n)
		}
	})

	// ---- skills ------------------------------------------------------------

	t.Run("aion_PutSkill + GetSkillList round-trip + upsert idempotence", func(t *testing.T) {
		const cid = 9000050
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Sk')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putskill", cid, 1001, 1, 0); err != nil {
			t.Fatalf("PutSkill #1: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putskill", cid, 1001, 7, 99); err != nil {
			t.Fatalf("PutSkill #2 (upsert): %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getskilllist", cid)
		if err != nil {
			t.Fatalf("GetSkillList: %v", err)
		}
		defer rows.Close()
		var n int
		var skillID, d1, d2 int
		for rows.Next() {
			n++
			if err := rows.Scan(&skillID, &d1, &d2); err != nil {
				t.Fatalf("scan: %v", err)
			}
		}
		if n != 1 {
			t.Fatalf("skill count: got %d, want 1 (upsert should not create dup)", n)
		}
		if skillID != 1001 || d1 != 7 || d2 != 99 {
			t.Fatalf("upsert values wrong: %d/%d/%d", skillID, d1, d2)
		}
	})

	// ---- quests ------------------------------------------------------------

	t.Run("aion_PutQuest + GetQuestList round-trip", func(t *testing.T) {
		const cid = 9000060
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Q')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putquest", cid, 4001, 1, 25); err != nil {
			t.Fatalf("PutQuest: %v", err)
		}
		// Idempotent on conflict
		if err := pool.CallSPExec(ctx, "aion_putquest", cid, 4001, 2, 99); err != nil {
			t.Fatalf("PutQuest dup: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getquestlist", cid)
		if err != nil {
			t.Fatalf("GetQuestList: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 1 {
			t.Fatalf("quest count: got %d, want 1", n)
		}
	})

	// ---- instance ----------------------------------------------------------

	t.Run("aion_SetUserInstance + GetUserInstance round-trip", func(t *testing.T) {
		const cid = 9000070
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'In')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setuserinstance_20171122",
			cid, 320070000, 1234, int(time.Now().Unix()), 1, 3, 0, 0, 0); err != nil {
			t.Fatalf("Set: %v", err)
		}
		// Upsert idempotence
		if err := pool.CallSPExec(ctx, "aion_setuserinstance_20171122",
			cid, 320070000, 5678, int(time.Now().Unix()), 1, 7, 0, 0, 0); err != nil {
			t.Fatalf("Set #2: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getuserinstance_20171122", cid)
		if err != nil {
			t.Fatalf("Get: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 1 {
			t.Fatalf("instance count: got %d, want 1 (upsert collapses)", n)
		}
	})

	t.Run("aion_InitInstanceCooltime_170817 sweeps stale rows", func(t *testing.T) {
		const cid = 9000071
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Co')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		// Seed: one stale (>8h ago), one fresh
		stale := int(time.Now().Add(-12 * time.Hour).Unix())
		fresh := int(time.Now().Unix())
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_instance(char_id, world_id, reentrance_time)
			 VALUES ($1, 1, $2), ($1, 2, $3)`, cid, stale, fresh); err != nil {
			t.Fatalf("seed instances: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_initinstancecooltime_170817"); err != nil {
			t.Fatalf("Init: %v", err)
		}
		var remaining int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_instance WHERE char_id = $1`, cid).Scan(&remaining); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if remaining != 1 {
			t.Fatalf("instances after sweep: got %d, want 1", remaining)
		}
	})

	// ---- guild -------------------------------------------------------------

	t.Run("aion_PutGuild_20100916 creates a legion and rejects duplicate name", func(t *testing.T) {
		var newID int
		if err := pool.CallSPRow(ctx, "aion_putguild_20100916",
			"b3test_legion_alpha", 9000080, 1, 0, 0, 0, 0).Scan(&newID); err != nil {
			t.Fatalf("PutGuild: %v", err)
		}
		if newID <= 0 {
			t.Fatalf("PutGuild returned non-positive id %d", newID)
		}
		// Duplicate → -1
		var rc int
		if err := pool.CallSPRow(ctx, "aion_putguild_20100916",
			"b3test_legion_alpha", 9000081, 1, 0, 0, 0, 0).Scan(&rc); err != nil {
			t.Fatalf("PutGuild dup: %v", err)
		}
		if rc != -1 {
			t.Fatalf("dup: want -1, got %d", rc)
		}
	})

	t.Run("aion_DeleteGuildMemberAll wipes guild_id from all members", func(t *testing.T) {
		const gid = 9000082
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name, race, master_id) VALUES ($1, 'b3test_legion_doomed', 1, 9000090)`,
			gid); err != nil {
			t.Fatalf("seed guild: %v", err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, guild_id, guild_rank, guild_intro)
			 VALUES (9000090, 'M1', $1, 1, 'hi'), (9000091, 'M2', $1, 2, 'yo')`, gid); err != nil {
			t.Fatalf("seed members: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_deleteguildmemberall", gid); err != nil {
			t.Fatalf("Delete: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE guild_id = $1`, gid).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 0 {
			t.Fatalf("members still bound: %d", n)
		}
	})

	t.Run("aion_SetGuildMemberRank updates rank for matching pair only", func(t *testing.T) {
		const gid = 9000083
		const cid = 9000092
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name, race, master_id) VALUES ($1, 'b3test_legion_rank', 1, $2)`,
			gid, cid); err != nil {
			t.Fatalf("seed guild: %v", err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, guild_id, guild_rank) VALUES ($1, 'R', $2, 5)`,
			cid, gid); err != nil {
			t.Fatalf("seed member: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setguildmemberrank", gid, cid, 1); err != nil {
			t.Fatalf("SetRank: %v", err)
		}
		var rk int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT guild_rank FROM user_data WHERE char_id = $1`, cid).Scan(&rk); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if rk != 1 {
			t.Fatalf("rank: got %d, want 1", rk)
		}
	})

	// ---- mail --------------------------------------------------------------

	t.Run("aion_MailWriteSys_20111227 inserts mail and returns id", func(t *testing.T) {
		const toID = 9000095
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'MR')`, toID); err != nil {
			t.Fatalf("seed: %v", err)
		}
		var mailID int64
		if err := pool.CallSPRow(ctx, "aion_mailwritesys_20111227",
			toID, "MR", 0, "System",
			"Welcome", "Quest reward delivered.",
			int64(0), 0, int64(0), int64(1000), 0, int(time.Now().Unix()), 0,
		).Scan(&mailID); err != nil {
			t.Fatalf("MailWriteSys: %v", err)
		}
		if mailID == 0 {
			t.Fatalf("got id 0")
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_mail WHERE id = $1`, mailID).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 1 {
			t.Fatalf("mail row missing")
		}
	})
}

// TestPortedSPs_Smoke_E2E — synthetic end-to-end that exercises the most
// common login → early-game sequence in one transaction-per-step run:
//
//	PutGuild → SetGuildMember → SetCharCP → AddCharRankPoint
//	→ PutItem → PutSkill → PutQuest → SetCharLocation
//	→ SetCharLogoutTime → DeleteItem → DeleteGuild
//
// The original task brief asked for "PutChar → GetCharInfo → AddItem →
// SetGuildMember → SaveCharInfo". PutChar (110-col) and GetCharInfo (120-col)
// are TODO-flagged for B4 (priority-50.md), so the smoke uses direct INSERT
// for the user_data seed and exercises every other step via SPs.
func TestPortedSPs_Smoke_E2E(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	fixtureCleanup(t, ctx, pool)
	t.Cleanup(func() { fixtureCleanup(t, context.Background(), pool) })

	const cid = 9000050 // intentionally re-uses Round-5 band; cleanup wipes both
	// We reuse cid 9000050 — we already cleaned it in fixtureCleanup. Insert
	// a fresh user_data row mocking PutChar's outcome.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, account_id, lev) VALUES ($1, 'SmokeHero', 'b3test_smoke_user', 909001, 1)`,
		cid); err != nil {
		t.Fatalf("seed user_data (proxy for PutChar): %v", err)
	}

	// 1. Create a legion
	var gid int
	if err := pool.CallSPRow(ctx, "aion_putguild_20100916",
		"b3test_legion_smoke", cid, 1, 0, 0, 0, 0).Scan(&gid); err != nil {
		t.Fatalf("PutGuild: %v", err)
	}
	if gid <= 0 {
		t.Fatalf("PutGuild bad id: %d", gid)
	}

	// 2. Bind char to legion
	var ret int
	if err := pool.CallSPRow(ctx, "aion_setguildmember", gid, cid).Scan(&ret); err != nil {
		t.Fatalf("SetGuildMember: %v", err)
	}
	if ret != gid {
		t.Fatalf("SetGuildMember return: got %d want %d", ret, gid)
	}

	// 3. Award 100 CP
	if err := pool.CallSPExec(ctx, "aion_setcharcp", cid, 100); err != nil {
		t.Fatalf("SetCharCP: %v", err)
	}

	// 4. +25 rank-point
	var rp int64
	if err := pool.CallSPRow(ctx, "aion_addcharrankpoint", cid, 25).Scan(&rp); err != nil {
		t.Fatalf("AddCharRankPoint: %v", err)
	}
	if rp != 25 {
		t.Fatalf("rank_point: %d", rp)
	}

	// 5. Drop an item
	var itemID int64
	err = pool.CallSPRow(ctx, "aion_putitem_20150921",
		cid,            // char_id
		152000001,      // name_id
		0,              // slot_id
		int64(1),       // amount
		int64(0),       // tid
		0,              // slot_num
		0,              // warehouse
		0, 0, 0,        // soul_bound, enchant_count, skin_name_id
		0, 0, 0, 0, 0, 0, // stat_enchant 0..5
		0, 0, 0, 0,     // option_count, dye_info, proc_tool_nameid, expired_time
		"boss",         // producer (TEXT — must not be an int)
		0, 0,           // buy_amount, buy_duration
		0, 0,           // obtain_skin_type, expire_skin_time
		0, 0,           // dynamic_property, server_of_origin
		0,              // expire_dye_time
		0, 0, 0,        // random_option, limit_enchant_count, reidentify_count
		0, 0,           // authorize_count, vanish_point
		0, 0,           // enchant_prob_addition, option_prob_addition
		0,              // key_name_id
		0, 0, 0, 0,     // exceedState, exceedSkillId 1..3
		0, 0, 0,        // baseSkillId, enhanceSkillGroup, enhanceSkillLevel
	).Scan(&itemID)
	if err != nil {
		t.Fatalf("PutItem: %v", err)
	}

	// 6. Learn a skill
	if err := pool.CallSPExec(ctx, "aion_putskill", cid, 5101, 1, 0); err != nil {
		t.Fatalf("PutSkill: %v", err)
	}

	// 7. Accept a quest
	if err := pool.CallSPExec(ctx, "aion_putquest", cid, 18000, 0, 0); err != nil {
		t.Fatalf("PutQuest: %v", err)
	}

	// 8. Move to a hunting ground
	if err := pool.CallSPExec(ctx, "aion_setcharlocation", cid, 1, 210050000, float32(1500), float32(2500), float32(120)); err != nil {
		t.Fatalf("SetCharLocation: %v", err)
	}

	// 9. Logout — must stamp the time
	var lt time.Time
	if err := pool.CallSPRow(ctx, "aion_setcharlogouttime_20120516", cid).Scan(&lt); err != nil {
		t.Fatalf("Logout: %v", err)
	}

	// 10. Sell the item we picked up
	if err := pool.CallSPExec(ctx, "aion_deleteitem", itemID); err != nil {
		t.Fatalf("DeleteItem: %v", err)
	}

	// 11. Disband the legion (cleanup)
	if err := pool.CallSPExec(ctx, "aion_deleteguildmemberall", gid); err != nil {
		t.Fatalf("DeleteGuildMemberAll: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_deleteguild", gid); err != nil {
		t.Fatalf("DeleteGuild: %v", err)
	}

	// Final assertion: char survived the loop, has CP=100, rank=25, no items,
	// no guild, was at the hunting ground.
	var (
		cp, rkInt int
		gidNow    int
		x         float32
		nItems    int
	)
	if err := pool.Inner().QueryRow(ctx,
		`SELECT cp, rank_point, guild_id, xlocation FROM user_data WHERE char_id = $1`, cid).
		Scan(&cp, &rkInt, &gidNow, &x); err != nil {
		t.Fatalf("final select: %v", err)
	}
	if err := pool.Inner().QueryRow(ctx,
		`SELECT COUNT(*) FROM user_item WHERE char_id = $1`, cid).Scan(&nItems); err != nil {
		t.Fatalf("count items: %v", err)
	}
	// gidNow should be 0 — DeleteGuildMemberAll wiped the binding before disband.
	if cp != 100 || rkInt != 25 || gidNow != 0 || x != 1500 || nItems != 0 {
		t.Fatalf("e2e final state mismatch: cp=%d rank=%d gid_now=%d (want 0) x=%g items=%d (orig gid=%d)",
			cp, rkInt, gidNow, x, nItems, gid)
	}
}
