// Package database — Round 9 (Track B7) integration tests for the 20 newly-
// ported NCSoft instance/condition/achievement stored procedures.
//
// All Round 9 SPs operate on the "instance/dungeon" axis (group play storage,
// even though the live group state itself stays in the world process).
// The tests follow the layout established by sp_pve_round{6,7,8}_test.go:
// each subtest is independent, fixtures live in the round-9 cleanup band
// 9_000_500..9_000_599, and the smoke E2E chain models a realistic
// "enter dungeon → progress → kill boss → reward" lifecycle.
//
// Round 9 SPs covered (20 total):
//   user_instance (3): aion_GetUserInstance, aion_SetUserInstance,
//                      aion_DeleteUserInstanceByServerId,
//                      aion_InitInstanceCooltime
//   instance design-time (3): aion_GetInstance, aion_SetInstance,
//                             aion_GetMaximumInstanceId
//   instance condition (4): aion_GetInstanceCondition, aion_SetInstanceCondition,
//                           aion_GetWorldExtConditionList, aion_SetWorldExtCondition
//   instance achievement (2): aion_GetInstanceAchievementList,
//                             aion_SetInstanceAchievement
//   abyss-OP extra count (2): aion_GetInstanceExtraCountAbyssOP,
//                             aion_SetInstanceExtraCountAbyssOP
//   monster bestiary (3): aion_GetMonsterAchievementList,
//                         aion_SetMonsterAchievement,
//                         aion_SetMonsterAchievementRewardReceived
//   no-op stubs (2): aion_GetInstanceDungeonValidityTermList,
//                    aion_SetInstanceDungeonValidityTermList
//
// Cleanup bands:
//   - char_id                              9_000_500..9_000_599 (round-9 char band)
//   - instance.instance_id                 9_500_001..9_500_999
//   - world_extcondition.world_num         9_500_001..9_500_999
//   - user_instance_achievement.char_id    9_000_500..9_000_599
//   - user_instance_extracount.char_id     9_000_500..9_000_599
//   - user_monster_achievement.char_id     9_000_500..9_000_599

package database

import (
	"context"
	"testing"
	"time"
)

// round9Cleanup wipes round-9 fixtures. Called pre+post each test run.
func round9Cleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, stmt := range []string{
		`DELETE FROM user_monster_achievement   WHERE char_id BETWEEN 9000500 AND 9000599`,
		`DELETE FROM user_instance_extracount   WHERE char_id BETWEEN 9000500 AND 9000599`,
		`DELETE FROM user_instance_achievement  WHERE char_id BETWEEN 9000500 AND 9000599`,
		`DELETE FROM user_instance              WHERE char_id BETWEEN 9000500 AND 9000599`,
		`DELETE FROM world_extcondition         WHERE world_num BETWEEN 9500001 AND 9500999`,
		`DELETE FROM instance                   WHERE instance_id BETWEEN 9500001 AND 9500999`,
		`DELETE FROM user_data                  WHERE char_id BETWEEN 9000500 AND 9000599`,
	} {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("round9Cleanup %q: %v", stmt, err)
		}
	}
}

// setupRound9 boots PG, runs migrations, opens a pool, and registers cleanup.
func setupRound9(t *testing.T) (*Pool, context.Context, context.CancelFunc) {
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
	t.Cleanup(cancel)

	round9Cleanup(t, ctx, pool)
	t.Cleanup(func() { round9Cleanup(t, context.Background(), pool) })
	return pool, ctx, cancel
}

// seedRound9Char inserts a minimal user_data row at char_id (in band 9000500..9000599).
func seedRound9Char(t *testing.T, ctx context.Context, p *Pool, charID int, name string) {
	t.Helper()
	_, err := p.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)
		 ON CONFLICT (char_id) DO NOTHING`,
		charID, name, "b7test_"+name)
	if err != nil {
		t.Fatalf("seedRound9Char: %v", err)
	}
}

// TestPortedSPs_Round9 — independent per-SP tests.
func TestPortedSPs_Round9(t *testing.T) {
	pool, ctx, _ := setupRound9(t)

	// =================================================================
	// user_instance / per-character entry-cooldown rows (3 SPs)
	// =================================================================

	t.Run("aion_SetUserInstance + aion_GetUserInstance roundtrip 6-col variant", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000501, "Raider1")
		// Seed a design-time instance so GetUserInstance's LEFT JOIN can return validity_time.
		if err := pool.CallSPExec(ctx, "aion_setinstance",
			9500001, 1700009999, 0, "phase_alpha"); err != nil {
			t.Fatalf("seed instance: %v", err)
		}
		// First call: INSERT path.
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000501, 220010000, 9500001, 1700000000, 1, 3); err != nil {
			t.Fatalf("set insert: %v", err)
		}
		// Second call (same char+world): UPDATE path with new values.
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000501, 220010000, 9500001, 1700000500, 1, 2); err != nil {
			t.Fatalf("set update: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getuserinstance", 9000501)
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		defer rows.Close()
		var n int
		var srvID, worldID, instID, reentry, count, validity int
		for rows.Next() {
			if err := rows.Scan(&srvID, &worldID, &instID, &reentry, &count, &validity); err != nil {
				t.Fatalf("scan: %v", err)
			}
			n++
		}
		if n != 1 || worldID != 220010000 || count != 2 || reentry != 1700000500 || validity != 1700009999 {
			t.Fatalf("get: n=%d world=%d count=%d reentry=%d validity=%d",
				n, worldID, count, reentry, validity)
		}
	})

	t.Run("aion_DeleteUserInstanceByServerId skips protected lobbies", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000502, "Raider2")
		// 3 entries on the same server: one in a protected lobby, two regular.
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000502, 302350000, 9500002, 1700000000, 99, 1); err != nil { // protected lobby
			t.Fatalf("seed lobby: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000502, 220010001, 9500003, 1700000000, 99, 1); err != nil {
			t.Fatalf("seed reg1: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000502, 220010002, 9500004, 1700000000, 99, 1); err != nil {
			t.Fatalf("seed reg2: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_deleteuserinstancebyserverid", 99); err != nil {
			t.Fatalf("delete: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_instance WHERE char_id=9000502 AND server_id=99`).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		// Only the protected lobby row should survive.
		if n != 1 {
			t.Fatalf("after delete: %d (want 1, only protected lobby)", n)
		}
		var worldID int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT world_id FROM user_instance WHERE char_id=9000502`).Scan(&worldID); err != nil {
			t.Fatalf("verify lobby: %v", err)
		}
		if worldID != 302350000 {
			t.Fatalf("survivor: world=%d (want 302350000)", worldID)
		}
	})

	t.Run("aion_InitInstanceCooltime reaps stale reentrance_time rows", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000503, "Raider3")
		// Stale row: reentrance_time = 0 (definitely older than now-8h).
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000503, 220020000, 9500005, 0, 1, 1); err != nil {
			t.Fatalf("seed stale: %v", err)
		}
		// Fresh row: reentrance_time near now.
		futureTime := int(time.Now().Unix()) + 3600
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000503, 220020001, 9500006, futureTime, 1, 1); err != nil {
			t.Fatalf("seed fresh: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_initinstancecooltime"); err != nil {
			t.Fatalf("init: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_instance WHERE char_id=9000503`).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("after init: %d (want 1, fresh only)", n)
		}
	})

	// =================================================================
	// instance design-time rows (3 SPs)
	// =================================================================

	t.Run("aion_SetInstance + aion_GetInstance returns valid rows; expired skipped", func(t *testing.T) {
		// 1 valid in the future, 1 already expired.
		validUntil := int(time.Now().Unix()) + 3600
		expiredAt := int(time.Now().Unix()) - 3600
		if err := pool.CallSPExec(ctx, "aion_setinstance",
			9500011, validUntil, 0, "valid_phase"); err != nil {
			t.Fatalf("set valid: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setinstance",
			9500012, expiredAt, 1, "expired_phase"); err != nil {
			t.Fatalf("set expired: %v", err)
		}
		// Update existing → exercise UPSERT path.
		if err := pool.CallSPExec(ctx, "aion_setinstance",
			9500011, validUntil+100, 5, "updated_phase"); err != nil {
			t.Fatalf("set update: %v", err)
		}
		now := int(time.Now().Unix())
		rows, err := pool.CallSP(ctx, "aion_getinstance", now)
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			var iid, vt, sp int
			var phase string
			if err := rows.Scan(&iid, &vt, &sp, &phase); err != nil {
				t.Fatalf("scan: %v", err)
			}
			// Filter to our band — other tests may have inserted rows.
			if iid >= 9500001 && iid <= 9500999 {
				if iid == 9500011 {
					if phase != "updated_phase" || sp != 5 || vt != validUntil+100 {
						t.Fatalf("upsert lost: phase=%q sp=%d vt=%d", phase, sp, vt)
					}
				} else if iid == 9500012 {
					t.Fatalf("expired row 9500012 leaked into result")
				}
				n++
			}
		}
		if n != 1 {
			t.Fatalf("rows in band: got %d, want 1", n)
		}
	})

	t.Run("aion_GetMaximumInstanceId returns max <0x90000000 and reaps expired", func(t *testing.T) {
		futureTime := int(time.Now().Unix()) + 3600
		expiredAt := int(time.Now().Unix()) - 3600
		// Two valid rows in our band; one expired row.
		if err := pool.CallSPExec(ctx, "aion_setinstance", 9500021, futureTime, 0, ""); err != nil {
			t.Fatalf("v1: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setinstance", 9500022, futureTime, 0, ""); err != nil {
			t.Fatalf("v2: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setinstance", 9500023, expiredAt, 0, ""); err != nil {
			t.Fatalf("exp: %v", err)
		}
		// Seed a user_instance to make MAX(instance_id) deterministic.
		seedRound9Char(t, ctx, pool, 9000504, "MaxOwner")
		if err := pool.CallSPExec(ctx, "aion_setuserinstance",
			9000504, 220030000, 9500022, futureTime, 1, 1); err != nil {
			t.Fatalf("seed ui: %v", err)
		}
		var maxID int
		if err := pool.CallSPRow(ctx, "aion_getmaximuminstanceid", int(time.Now().Unix())).Scan(&maxID); err != nil {
			t.Fatalf("call: %v", err)
		}
		// At minimum we must see our seeded user_instance row (9500022).
		if maxID < 9500022 {
			t.Fatalf("maxID=%d, want >=9500022", maxID)
		}
		// Expired instance row should be reaped.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM instance WHERE instance_id=9500023`).Scan(&n); err != nil {
			t.Fatalf("verify reap: %v", err)
		}
		if n != 0 {
			t.Fatalf("expired instance not reaped: %d", n)
		}
	})

	// =================================================================
	// instance condition (4 SPs) — KV state per (world_type, world_num, variable).
	// =================================================================

	t.Run("aion_SetInstanceCondition + aion_GetInstanceCondition roundtrip", func(t *testing.T) {
		futureTime := int(time.Now().Unix()) + 3600
		if err := pool.CallSPExec(ctx, "aion_setinstance", 9500031, futureTime, 0, ""); err != nil {
			t.Fatalf("seed inst: %v", err)
		}
		// First call inserts.
		if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
			9500031, "boss_killed", 12345, 1); err != nil {
			t.Fatalf("set ins: %v", err)
		}
		// Second call updates (same hash → matches single row).
		if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
			9500031, "boss_killed", 12345, 5); err != nil {
			t.Fatalf("set upd: %v", err)
		}
		// Add a different variable too.
		if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
			9500031, "trap_disarmed", 67890, 1); err != nil {
			t.Fatalf("set 2: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getinstancecondition", int(time.Now().Unix()))
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		defer rows.Close()
		seen := map[string]int{}
		for rows.Next() {
			var wn, val int
			var v string
			if err := rows.Scan(&wn, &v, &val); err != nil {
				t.Fatalf("scan: %v", err)
			}
			if wn == 9500031 {
				seen[v] = val
			}
		}
		if seen["boss_killed"] != 5 {
			t.Fatalf("boss_killed: got %d, want 5", seen["boss_killed"])
		}
		if seen["trap_disarmed"] != 1 {
			t.Fatalf("trap_disarmed: got %d, want 1", seen["trap_disarmed"])
		}
	})

	t.Run("aion_SetWorldExtCondition + aion_GetWorldExtConditionList for persistent worlds", func(t *testing.T) {
		// world_type=0 (persistent world). Use a band-safe world_num.
		if err := pool.CallSPExec(ctx, "aion_setworldextcondition",
			9500041, "season_boss_alive", 11111, 1); err != nil {
			t.Fatalf("set: %v", err)
		}
		// Update.
		if err := pool.CallSPExec(ctx, "aion_setworldextcondition",
			9500041, "season_boss_alive", 11111, 0); err != nil {
			t.Fatalf("set update: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getworldextconditionlist")
		if err != nil {
			t.Fatalf("list: %v", err)
		}
		defer rows.Close()
		var matched bool
		for rows.Next() {
			var wn, val int
			var v string
			if err := rows.Scan(&wn, &v, &val); err != nil {
				t.Fatalf("scan: %v", err)
			}
			if wn == 9500041 && v == "season_boss_alive" {
				if val != 0 {
					t.Fatalf("upsert lost: %d", val)
				}
				matched = true
			}
		}
		if !matched {
			t.Fatalf("did not find seeded condition")
		}
	})

	// =================================================================
	// instance achievement blob (2 SPs)
	// =================================================================

	t.Run("aion_SetInstanceAchievement + aion_GetInstanceAchievementList roundtrip", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000510, "Achiever")
		blob1 := []byte{0x01, 0x02, 0x03, 0x04}
		blob2 := []byte{0xFF, 0xEE, 0xDD}
		// (world, page, version) combos: 2 distinct rows.
		if err := pool.CallSPExec(ctx, "aion_setinstanceachievement",
			9000510, 220040000, 0, 1, blob1); err != nil {
			t.Fatalf("set1: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setinstanceachievement",
			9000510, 220040001, 0, 1, blob2); err != nil {
			t.Fatalf("set2: %v", err)
		}
		// Update first row's blob (same key).
		blob1upd := []byte{0xAA, 0xBB, 0xCC, 0xDD, 0xEE}
		if err := pool.CallSPExec(ctx, "aion_setinstanceachievement",
			9000510, 220040000, 0, 1, blob1upd); err != nil {
			t.Fatalf("set1 upd: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getinstanceachievementlist", 9000510)
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		defer rows.Close()
		got := map[int][]byte{}
		for rows.Next() {
			var wid, sp, ver int
			var data []byte
			if err := rows.Scan(&wid, &sp, &ver, &data); err != nil {
				t.Fatalf("scan: %v", err)
			}
			got[wid] = data
		}
		if len(got) != 2 {
			t.Fatalf("rows: %d, want 2", len(got))
		}
		if string(got[220040000]) != string(blob1upd) {
			t.Fatalf("upsert lost: got %v", got[220040000])
		}
		if string(got[220040001]) != string(blob2) {
			t.Fatalf("blob2 corrupt: got %v", got[220040001])
		}
	})

	// =================================================================
	// abyss-OP extra count (2 SPs) — daily-reset counter per (char, map).
	// =================================================================

	t.Run("aion_SetInstanceExtraCountAbyssOP map>0 upserts; map=0 zeroes all", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000520, "AbyssWarrior")
		nextReset := int64(time.Now().Unix()) + 86400
		// Map 1: insert.
		if err := pool.CallSPExec(ctx, "aion_setinstanceextracountabyssop",
			9000520, 1, int16(3), nextReset); err != nil {
			t.Fatalf("set1: %v", err)
		}
		// Map 1: update count.
		if err := pool.CallSPExec(ctx, "aion_setinstanceextracountabyssop",
			9000520, 1, int16(7), nextReset+10); err != nil {
			t.Fatalf("set1 upd: %v", err)
		}
		// Map 2: insert.
		if err := pool.CallSPExec(ctx, "aion_setinstanceextracountabyssop",
			9000520, 2, int16(2), nextReset); err != nil {
			t.Fatalf("set2: %v", err)
		}
		// Read with op_reset_time below all rows → both visible.
		rows, err := pool.CallSP(ctx, "aion_getinstanceextracountabyssop",
			9000520, int64(0))
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		var seen []int
		for rows.Next() {
			var mapNum int
			var cnt int16
			var nrt int64
			if err := rows.Scan(&mapNum, &cnt, &nrt); err != nil {
				rows.Close()
				t.Fatalf("scan: %v", err)
			}
			if mapNum == 1 && cnt != 7 {
				rows.Close()
				t.Fatalf("upsert lost: cnt=%d (want 7)", cnt)
			}
			seen = append(seen, mapNum)
		}
		rows.Close()
		if len(seen) != 2 {
			t.Fatalf("read: %d rows, want 2", len(seen))
		}
		// map=0 wipe path: zeroes next_reset_time on every row of this char.
		if err := pool.CallSPExec(ctx, "aion_setinstanceextracountabyssop",
			9000520, 0, int16(0), int64(0)); err != nil {
			t.Fatalf("wipe: %v", err)
		}
		// Now read with op_reset_time=1 → all rows have nrt=0 < 1 → zero rows.
		rows2, err := pool.CallSP(ctx, "aion_getinstanceextracountabyssop",
			9000520, int64(1))
		if err != nil {
			t.Fatalf("get post-wipe: %v", err)
		}
		var n int
		for rows2.Next() {
			n++
		}
		rows2.Close()
		if n != 0 {
			t.Fatalf("post-wipe: %d rows visible (want 0)", n)
		}
		// Verify rows physically still exist (T-SQL does NOT delete).
		var existing int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_instance_extracount WHERE char_id=9000520`).Scan(&existing); err != nil {
			t.Fatalf("phys: %v", err)
		}
		if existing != 2 {
			t.Fatalf("rows physically removed: %d (T-SQL only zeros next_reset_time)", existing)
		}
	})

	// =================================================================
	// monster bestiary (3 SPs)
	// =================================================================

	t.Run("aion_SetMonsterAchievement preserves reward_received on UPDATE branch", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000530, "Hunter1")
		// First call inserts row with reward_received=0.
		if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
			9000530, 555, 10, int16(1)); err != nil {
			t.Fatalf("set1: %v", err)
		}
		// Manually bump reward_received to mimic a claim happening between calls.
		if _, err := pool.Inner().Exec(ctx,
			`UPDATE user_monster_achievement SET reward_received=2
			  WHERE char_id=9000530 AND achieve_id=555`); err != nil {
			t.Fatalf("manual bump: %v", err)
		}
		// Second SetMonsterAchievement (UPDATE branch): must NOT touch reward_received.
		if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
			9000530, 555, 25, int16(2)); err != nil {
			t.Fatalf("set2: %v", err)
		}
		var cnt int
		var grade, rr int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT achieved_count, achieved_grade, reward_received
			   FROM user_monster_achievement WHERE char_id=9000530 AND achieve_id=555`).
			Scan(&cnt, &grade, &rr); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cnt != 25 || grade != 2 {
			t.Fatalf("count/grade: cnt=%d grade=%d (want 25/2)", cnt, grade)
		}
		if rr != 2 {
			t.Fatalf("reward_received clobbered: %d (must remain 2)", rr)
		}
	})

	t.Run("aion_GetMonsterAchievementList returns all rows for char", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000531, "Hunter2")
		for _, aid := range []int{1, 2, 3} {
			if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
				9000531, aid, aid*10, int16(aid)); err != nil {
				t.Fatalf("seed %d: %v", aid, err)
			}
		}
		rows, err := pool.CallSP(ctx, "aion_getmonsterachievementlist", 9000531)
		if err != nil {
			t.Fatalf("list: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 3 {
			t.Fatalf("rows: %d, want 3", n)
		}
	})

	t.Run("aion_SetMonsterAchievementRewardReceived enforces sequential claim gate", func(t *testing.T) {
		seedRound9Char(t, ctx, pool, 9000532, "Hunter3")
		if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
			9000532, 777, 100, int16(3)); err != nil {
			t.Fatalf("seed: %v", err)
		}
		// reward_received starts at 0. Try to claim grade 2 → must fail (need grade 1 first).
		var grade, rc int
		if err := pool.CallSPRow(ctx, "aion_setmonsterachievementrewardreceived",
			9000532, 777, int16(2)).Scan(&grade, &rc); err != nil {
			t.Fatalf("call skip: %v", err)
		}
		if rc != 0 || grade != -1 {
			t.Fatalf("skip-claim should fail: rc=%d grade=%d", rc, grade)
		}
		// Now claim grade 1 → succeeds.
		if err := pool.CallSPRow(ctx, "aion_setmonsterachievementrewardreceived",
			9000532, 777, int16(1)).Scan(&grade, &rc); err != nil {
			t.Fatalf("call 1: %v", err)
		}
		if rc != 1 || grade != 1 {
			t.Fatalf("grade-1 claim: rc=%d grade=%d (want 1/1)", rc, grade)
		}
		// Then claim grade 2 → succeeds.
		if err := pool.CallSPRow(ctx, "aion_setmonsterachievementrewardreceived",
			9000532, 777, int16(2)).Scan(&grade, &rc); err != nil {
			t.Fatalf("call 2: %v", err)
		}
		if rc != 1 || grade != 2 {
			t.Fatalf("grade-2 claim: rc=%d grade=%d", rc, grade)
		}
		// Replay grade 2 (idempotent attempt) → must fail (reward_received already 2).
		if err := pool.CallSPRow(ctx, "aion_setmonsterachievementrewardreceived",
			9000532, 777, int16(2)).Scan(&grade, &rc); err != nil {
			t.Fatalf("call replay: %v", err)
		}
		if rc != 0 || grade != -1 {
			t.Fatalf("replay should fail: rc=%d grade=%d", rc, grade)
		}
	})

	// =================================================================
	// no-op stubs (2)
	// =================================================================

	t.Run("aion_GetInstanceDungeonValidityTermList returns zero rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getinstancedungeonvaliditytermlist")
		if err != nil {
			t.Fatalf("call: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("stub returned rows: %d", n)
		}
	})

	t.Run("aion_SetInstanceDungeonValidityTermList no-ops cleanly", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setinstancedungeonvaliditytermlist"); err != nil {
			t.Fatalf("call: %v", err)
		}
	})
}

// TestPortedSPs_Smoke_E2E_Round9 — full instance lifecycle chain.
//
// Models a player completing a dungeon: design-time create → enter →
// progress KV state → log achievement blob → kill boss → claim reward →
// daily reset.
//
// Chain (10 steps):
//   D1 SetInstance              — design-time row (validity_time = now+1h)
//   D2 GetInstance              — verify it's listed as valid
//   D3 SetUserInstance          — player checks in (entry record)
//   D4 GetUserInstance          — verify the row + JOINed validity_time
//   D5 SetInstanceCondition ×2  — two KV state vars (boss_hp, trap_state)
//   D6 GetInstanceCondition     — verify both visible
//   D7 SetInstanceAchievement   — completion blob
//   D8 SetMonsterAchievement    — boss kill counted in bestiary
//   D9 SetMonsterAchievementRewardReceived ×2 — sequential claim grade 1, 2
//   D10 InitInstanceCooltime    — daily reset, but our entry is fresh (preserved)
func TestPortedSPs_Smoke_E2E_Round9(t *testing.T) {
	pool, ctx, _ := setupRound9(t)

	const (
		charID    = 9000550
		instID    = 9500100
		bossWorld = 220050000
		bossID    = 1001
	)
	seedRound9Char(t, ctx, pool, charID, "E2EHero")
	validUntil := int(time.Now().Unix()) + 3600

	// D1: design-time instance.
	if err := pool.CallSPExec(ctx, "aion_setinstance",
		instID, validUntil, 0, "phase_start"); err != nil {
		t.Fatalf("D1: %v", err)
	}

	// D2: verify SetInstance is observable through GetInstance.
	rows, err := pool.CallSP(ctx, "aion_getinstance", int(time.Now().Unix()))
	if err != nil {
		t.Fatalf("D2: %v", err)
	}
	var found bool
	for rows.Next() {
		var iid, vt, sp int
		var ph string
		if err := rows.Scan(&iid, &vt, &sp, &ph); err != nil {
			rows.Close()
			t.Fatalf("D2 scan: %v", err)
		}
		if iid == instID && ph == "phase_start" {
			found = true
		}
	}
	rows.Close()
	if !found {
		t.Fatalf("D2: instance not visible")
	}

	// D3: player checks in.
	reentry := int(time.Now().Unix())
	if err := pool.CallSPExec(ctx, "aion_setuserinstance",
		charID, bossWorld, instID, reentry, 1, 1); err != nil {
		t.Fatalf("D3: %v", err)
	}

	// D4: verify check-in + JOINed validity_time.
	rows2, err := pool.CallSP(ctx, "aion_getuserinstance", charID)
	if err != nil {
		t.Fatalf("D4: %v", err)
	}
	var srvID, worldID, instGet, reentryGet, count, vt int
	var n int
	for rows2.Next() {
		if err := rows2.Scan(&srvID, &worldID, &instGet, &reentryGet, &count, &vt); err != nil {
			rows2.Close()
			t.Fatalf("D4 scan: %v", err)
		}
		n++
	}
	rows2.Close()
	if n != 1 || worldID != bossWorld || instGet != instID || vt != validUntil {
		t.Fatalf("D4: n=%d world=%d inst=%d vt=%d", n, worldID, instGet, vt)
	}

	// D5: two KV state vars on the instance.
	if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
		instID, "boss_hp", 0xB055, 100); err != nil {
		t.Fatalf("D5a: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
		instID, "trap_state", 0x7AAF, 0); err != nil {
		t.Fatalf("D5b: %v", err)
	}
	// Mid-fight tick: drop boss_hp.
	if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
		instID, "boss_hp", 0xB055, 50); err != nil {
		t.Fatalf("D5c: %v", err)
	}

	// D6: verify both KV reads.
	rows3, err := pool.CallSP(ctx, "aion_getinstancecondition", int(time.Now().Unix()))
	if err != nil {
		t.Fatalf("D6: %v", err)
	}
	kv := map[string]int{}
	for rows3.Next() {
		var wn, val int
		var v string
		if err := rows3.Scan(&wn, &v, &val); err != nil {
			rows3.Close()
			t.Fatalf("D6 scan: %v", err)
		}
		if wn == instID {
			kv[v] = val
		}
	}
	rows3.Close()
	if kv["boss_hp"] != 50 {
		t.Fatalf("D6 boss_hp: %d", kv["boss_hp"])
	}
	if _, ok := kv["trap_state"]; !ok {
		t.Fatalf("D6 trap_state missing")
	}

	// D7: completion blob.
	clearBlob := []byte{0x01, 0xFF, 0xAA, 0x55}
	if err := pool.CallSPExec(ctx, "aion_setinstanceachievement",
		charID, bossWorld, 0, 1, clearBlob); err != nil {
		t.Fatalf("D7: %v", err)
	}

	// D8: bestiary tally.
	if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
		charID, bossID, 1, int16(1)); err != nil {
		t.Fatalf("D8: %v", err)
	}

	// D9: claim grade 1 then grade 2 reward (must be sequential).
	var grade, rc int
	if err := pool.CallSPRow(ctx, "aion_setmonsterachievementrewardreceived",
		charID, bossID, int16(1)).Scan(&grade, &rc); err != nil {
		t.Fatalf("D9a: %v", err)
	}
	if rc != 1 || grade != 1 {
		t.Fatalf("D9a result: rc=%d grade=%d", rc, grade)
	}
	// Bump bestiary to grade 2 (more kills) so we may claim grade 2.
	if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
		charID, bossID, 5, int16(2)); err != nil {
		t.Fatalf("D9 bump: %v", err)
	}
	if err := pool.CallSPRow(ctx, "aion_setmonsterachievementrewardreceived",
		charID, bossID, int16(2)).Scan(&grade, &rc); err != nil {
		t.Fatalf("D9b: %v", err)
	}
	if rc != 1 || grade != 2 {
		t.Fatalf("D9b result: rc=%d grade=%d", rc, grade)
	}

	// D10: daily-reset cron — fresh entry must survive (reentrance_time near now).
	if err := pool.CallSPExec(ctx, "aion_initinstancecooltime"); err != nil {
		t.Fatalf("D10: %v", err)
	}
	var stillThere int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT COUNT(*) FROM user_instance WHERE char_id=$1 AND world_id=$2`,
		charID, bossWorld).Scan(&stillThere); err != nil {
		t.Fatalf("D10 verify: %v", err)
	}
	if stillThere != 1 {
		t.Fatalf("D10: fresh entry was reaped (count=%d)", stillThere)
	}

	t.Logf("E2E Round 9 chain complete: char %d cleared instance %d (world %d), "+
		"claimed grade 1+2 boss reward, fresh entry survived daily reset",
		charID, instID, bossWorld)
}
