// Package database — Round 10 (F1) integration tests for the character
// lifecycle stored procedures.
//
// Round 10 closes the build→list→select→login→logout→delete loop that was
// broken before this round (the actual aion_DeleteChar purge, the
// ClearCharDeleteTime restore, the GetDeletedCharList sweeper-source, plus
// six cascade-Delete helpers were all missing — the player could create a
// character but never actually be removed from the database, and the
// soft-delete cancel button had no SP to call).
//
// Round 10 SPs covered (12 total):
//   purge       (3): aion_DeleteChar, aion_ClearCharDeleteTime,
//                    aion_GetDeletedCharList
//   cascade-Del (6): aion_DeleteItemByChar, aion_DeleteAllSkill,
//                    aion_DeleteAllQuest, aion_DeleteAllAbnormalStatus,
//                    aion_DeleteEmotion, aion_DeleteFamiliar,
//                    aion_DeleteFinishedQuest
//   load helper (2): aion_GetCharInfoBasic,
//                    aion_GetHighestLevelCharacterOfAccount
//
// Cleanup band: char_id 9_010_000..9_010_099 (Round 10 reserve, distinct
// from Round 6's b4test_ band so the lifecycle E2E does not collide with
// existing PutChar test rows).
package database

import (
	"context"
	"database/sql"
	"testing"
	"time"
)

// round10Cleanup wipes Round-10 fixtures across every table the SPs touch.
// Run pre+post each test invocation so reruns are deterministic.
func round10Cleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, stmt := range []string{
		`DELETE FROM user_promotion_cooltime WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_familiar           WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_emotion            WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_abnormal_status    WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_finished_quest     WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_quest              WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_skill              WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_item_attribute     WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9010000 AND 9010099)`,
		`DELETE FROM user_item_polish        WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9010000 AND 9010099)`,
		`DELETE FROM user_item_charge        WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9010000 AND 9010099)`,
		`DELETE FROM user_item_option        WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_item               WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_data               WHERE char_id BETWEEN 9010000 AND 9010099`,
		`DELETE FROM user_data               WHERE user_id LIKE 'r10_%'`,
		`DELETE FROM user_data               WHERE account_id BETWEEN 9100000 AND 9100099`,
	} {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("round10Cleanup %q: %v", stmt, err)
		}
	}
}

// setupRound10 boots PG, runs migrations, opens a pool, and registers
// cleanup. Mirror of setupRound{6..9}.
func setupRound10(t *testing.T) (*Pool, context.Context, context.CancelFunc) {
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

	round10Cleanup(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		round10Cleanup(t, bg, pool)
	})
	return pool, ctx, cancel
}

// seedCharRow inserts one user_data row for the per-SP unit subtests. The
// E2E chain test below does NOT use this — it goes through PutChar instead.
// This helper exists so the per-SP subtests stay tight (no 110-arg PutChar
// noise) while still validating the SP body in isolation.
func seedCharRow(t *testing.T, ctx context.Context, p *Pool, charID, accountID int, name string) {
	t.Helper()
	_, err := p.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, user_id, name, account_id, account_name,
		                       race, class, lev, world)
		 VALUES ($1, $2, $2, $3, 'r10_acct', 1, 1, 50, 210050000)`,
		charID, name, accountID,
	)
	if err != nil {
		t.Fatalf("seedCharRow(%d): %v", charID, err)
	}
}

// callPutChar wraps the 110-arg aion_putchar_20160620 invocation so the E2E
// chain test reads cleanly. Defaults reflect the create-character path:
// race=Elyos, class=Warrior, gender=male, starter Poeta map. Caller supplies
// the unique fields that drive the assertions.
func callPutChar(t *testing.T, ctx context.Context, p *Pool, name string, accountID int, accountName string) (int, time.Time) {
	t.Helper()
	var (
		rc      int
		newID   int
		created time.Time
	)
	err := p.CallSPRow(ctx, "aion_putchar_20160620",
		name,                       // user_id
		accountID,                  // account_id
		accountName,                // account_name
		0,                          // race (Elyos)
		1,                          // class (Warrior)
		0,                          // gender (male)
		0xFFFFFF, 0xCCCCCC, 0xFFFFFF, 0xAAAAAA, // colors
		1, 1,                       // face_type, hair_type
		float64(1.0),               // scale
		1, 0, 0,                    // voice, feat1, feat2
		0, 0,                       // bump, expression
		170010,                     // name_id
		1,                          // org_server
		210020000,                  // world (Poeta)
		float32(1498), float32(1563), float32(193), // xyz (starter spawn)
		0,                          // dir
		500, 300,                   // hp, mp
		0,                          // builder
		1,                          // lev
		210020000, float32(1498), float32(1563), float32(193), // resurrect = spawn
		0,                          // inventory_growth
		1,                          // feat_version
		0, 0, 0, 0, 0, 0, 0, 0,     // face_shape..eye_tail
		0, 0, 0,                    // eyeblow_*
		0, 0, 0, 0,                 // nose_*
		0,                          // cheek_shape
		0, 0, 0, 0, 0,              // mouth_*/lip_*
		0, 0,                       // jaw_pos, jaw_shape
		0, 0,                       // ear_shape, head_size
		0, 0, 0,                    // neck_*, shoulder
		0, 0, 0, 0,                 // upper..hip
		0, 0, 0, 0,                 // arm..foot
		0, 0,                       // face_ratio, wing
		1, 1, 1,                    // arm_length, leg_length, shoulder_width
		0,                          // head_figure
		0, 0, 0, 0,                 // head_eye_type/dark_tail/eye_color2/eye_lash
		0, 0,                       // head_eye_size, upper_height
		0, 0, 0,                    // arm_lower, hand_length, leg_lower
		0,                          // is_jumping_character
	).Scan(&rc, &newID, &created)
	if err != nil {
		t.Fatalf("callPutChar(%s): %v", name, err)
	}
	if rc != 0 {
		t.Fatalf("callPutChar(%s): rc=%d, want 0", name, rc)
	}
	if newID <= 0 {
		t.Fatalf("callPutChar(%s): non-positive char_id %d", name, newID)
	}
	return newID, created
}

// TestPortedSPs_R10_CharLifecycle — 12 per-SP unit subtests + 1 E2E chain.
func TestPortedSPs_R10_CharLifecycle(t *testing.T) {
	pool, ctx, cancel := setupRound10(t)
	defer cancel()

	// =========================================================================
	// Per-SP unit subtests (use seedCharRow so each is independent of PutChar).
	// =========================================================================

	t.Run("aion_DeleteChar removes the user_data row", func(t *testing.T) {
		const cid = 9010001
		seedCharRow(t, ctx, pool, cid, 9100001, "r10_delchar")
		if err := pool.CallSPExec(ctx, "aion_deletechar", cid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_data WHERE char_id=$1`, cid).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("char still present after delete: count=%d", n)
		}
	})

	t.Run("aion_ClearCharDeleteTime zeroes delete_date", func(t *testing.T) {
		const cid = 9010002
		seedCharRow(t, ctx, pool, cid, 9100002, "r10_clear")
		// First mark for delete.
		if err := pool.CallSPExec(ctx, "aion_setchardeletetime", cid, 1700000000); err != nil {
			t.Fatalf("set: %v", err)
		}
		// Then clear it.
		if err := pool.CallSPExec(ctx, "aion_clearchardeletetime", cid); err != nil {
			t.Fatalf("clear: %v", err)
		}
		var dd int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT delete_date FROM user_data WHERE char_id=$1`, cid).Scan(&dd); err != nil {
			t.Fatalf("read: %v", err)
		}
		if dd != 0 {
			t.Fatalf("delete_date not cleared: got %d", dd)
		}
	})

	t.Run("aion_GetDeletedCharList yields rows with elapsed delete_date", func(t *testing.T) {
		const (
			cidPending = 9010010 // future delete_date — should NOT be listed
			cidElapsed = 9010011 // past delete_date — should be listed
		)
		seedCharRow(t, ctx, pool, cidPending, 9100010, "r10_pending")
		seedCharRow(t, ctx, pool, cidElapsed, 9100011, "r10_elapsed")
		// pending — delete_date = now+1day
		if err := pool.CallSPExec(ctx, "aion_setchardeletetime", cidPending, int(time.Now().Unix()+86400)); err != nil {
			t.Fatalf("setpending: %v", err)
		}
		// elapsed — delete_date in the past
		if err := pool.CallSPExec(ctx, "aion_setchardeletetime", cidElapsed, 1700000000); err != nil {
			t.Fatalf("setelapsed: %v", err)
		}

		rows, err := pool.CallSP(ctx, "aion_getdeletedcharlist", 1, int(time.Now().Unix()))
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		seen := map[int]bool{}
		for rows.Next() {
			var (
				cid, accID, gid, grank int
				userID, accName        string
			)
			if err := rows.Scan(&cid, &userID, &accID, &accName, &gid, &grank); err != nil {
				t.Fatalf("scan: %v", err)
			}
			seen[cid] = true
		}
		if !seen[cidElapsed] {
			t.Fatalf("elapsed char_id %d missing from sweeper list", cidElapsed)
		}
		if seen[cidPending] {
			t.Fatalf("pending char_id %d should not appear", cidPending)
		}
	})

	t.Run("aion_DeleteItemByChar moves items to warehouse=10", func(t *testing.T) {
		const cid = 9010020
		seedCharRow(t, ctx, pool, cid, 9100020, "r10_delitem")
		// Two items in inventory (warehouse=0), one already in trash (warehouse=10).
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_item(char_id, name_id, warehouse) VALUES
			 ($1, 100, 0), ($1, 200, 0), ($1, 300, 10)`, cid)
		if err != nil {
			t.Fatalf("seed items: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_deleteitembychar", cid, 0); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item WHERE char_id=$1 AND warehouse=10`, cid).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		// 2 archived (from inv) + 1 already there = 3.
		if n != 3 {
			t.Fatalf("warehouse=10 count: got %d, want 3", n)
		}
	})

	t.Run("aion_DeleteAllSkill wipes all skills for the char", func(t *testing.T) {
		const cid = 9010030
		seedCharRow(t, ctx, pool, cid, 9100030, "r10_delskill")
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_skill(char_id, skill_id) VALUES ($1, 100), ($1, 101), ($1, 102)`, cid)
		if err := pool.CallSPExec(ctx, "aion_deleteallskill", cid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_skill WHERE char_id=$1`, cid).Scan(&n)
		if n != 0 {
			t.Fatalf("skills not wiped: count=%d", n)
		}
	})

	t.Run("aion_DeleteAllQuest wipes both active and finished quest tables", func(t *testing.T) {
		const cid = 9010040
		seedCharRow(t, ctx, pool, cid, 9100040, "r10_delquest")
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_quest(char_id, quest_id) VALUES ($1, 1001), ($1, 1002)`, cid)
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_finished_quest(char_id, quest_id) VALUES ($1, 9001)`, cid)
		if err := pool.CallSPExec(ctx, "aion_deleteallquest", cid); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var na, nf int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_quest WHERE char_id=$1`, cid).Scan(&na)
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_finished_quest WHERE char_id=$1`, cid).Scan(&nf)
		if na != 0 || nf != 0 {
			t.Fatalf("quests not wiped: active=%d finished=%d", na, nf)
		}
	})

	t.Run("aion_DeleteAllAbnormalStatus wipes the buff/debuff table", func(t *testing.T) {
		const cid = 9010050
		// 00210 加了 UNIQUE(char_id, skill_id)；裸 INSERT 必须填 skill_id 才不撞约束。
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_abnormal_status(char_id, abnormal_id, skill_id, remain_time_ms)
			 VALUES ($1, 1, 1, 1000), ($1, 2, 2, 2000)`, cid)
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
	})

	t.Run("aion_DeleteEmotion removes emotes of the given type only", func(t *testing.T) {
		const cid = 9010060
		// 00199 enforces UNIQUE(char_id, emotion_type) — NCSoft 实际语义是
		// 每个 char 每个 emotion_type 最多 1 行。所以测试只能播种"两个不同
		// type 各 1 行"，验证 DeleteEmotion 仅清自己 type、不动邻居 type。
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_emotion(char_id, emotion_id, emotion_type) VALUES
			 ($1, 100, 0), ($1, 200, 1)`, cid); err != nil {
			t.Fatalf("seed user_emotion: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_deleteemotion", cid, 0); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var nType0, nType1 int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_emotion WHERE char_id=$1 AND emotion_type=0`, cid).Scan(&nType0)
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_emotion WHERE char_id=$1 AND emotion_type=1`, cid).Scan(&nType1)
		if nType0 != 0 {
			t.Fatalf("type=0 not wiped: count=%d", nType0)
		}
		if nType1 != 1 {
			t.Fatalf("type=1 unintentionally wiped: count=%d", nType1)
		}
	})

	t.Run("aion_DeleteFamiliar soft-deletes (deleted=1) and bumps update_time", func(t *testing.T) {
		const cid = 9010070
		var famID int64
		err := pool.Inner().QueryRow(ctx,
			`INSERT INTO user_familiar(char_id, familiar_template_id, name)
			 VALUES ($1, 5001, 'Fluffy') RETURNING id`, cid).Scan(&famID)
		if err != nil {
			t.Fatalf("seed familiar: %v", err)
		}
		const updateTime int64 = 1700000999
		if err := pool.CallSPExec(ctx, "aion_deletefamiliar", famID, cid, updateTime); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var deleted int
		var ut int64
		_ = pool.Inner().QueryRow(ctx,
			`SELECT deleted, update_time FROM user_familiar WHERE id=$1`, famID).Scan(&deleted, &ut)
		if deleted != 1 {
			t.Fatalf("deleted flag: got %d, want 1", deleted)
		}
		if ut != updateTime {
			t.Fatalf("update_time: got %d, want %d", ut, updateTime)
		}
	})

	t.Run("aion_DeleteFinishedQuest removes one quest only", func(t *testing.T) {
		const cid = 9010080
		seedCharRow(t, ctx, pool, cid, 9100080, "r10_delfq")
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_finished_quest(char_id, quest_id) VALUES
			 ($1, 5001), ($1, 5002), ($1, 5003)`, cid)
		if err := pool.CallSPExec(ctx, "aion_deletefinishedquest", cid, 5002); err != nil {
			t.Fatalf("CallSPExec: %v", err)
		}
		var n int
		_ = pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_finished_quest WHERE char_id=$1`, cid).Scan(&n)
		if n != 2 {
			t.Fatalf("finished_quest count: got %d, want 2", n)
		}
	})

	t.Run("aion_GetCharInfoBasic returns the 5-column header", func(t *testing.T) {
		const (
			cid = 9010090
			aid = 9100090
		)
		seedCharRow(t, ctx, pool, cid, aid, "r10_basic")
		var (
			gotAcc, gotGID, gotGRank int
			gotClass                 int16
			gotUserID                string
		)
		err := pool.CallSPRow(ctx, "aion_getcharinfobasic", cid).Scan(
			&gotAcc, &gotClass, &gotGID, &gotUserID, &gotGRank)
		if err != nil {
			t.Fatalf("Scan: %v", err)
		}
		if gotAcc != aid {
			t.Fatalf("account_id: got %d, want %d", gotAcc, aid)
		}
		if gotUserID != "r10_basic" {
			t.Fatalf("user_id: got %q, want r10_basic", gotUserID)
		}
		if gotClass != 1 {
			t.Fatalf("class: got %d, want 1", gotClass)
		}
	})

	t.Run("aion_GetHighestLevelCharacterOfAccount returns the top-level char", func(t *testing.T) {
		const aid = 9100091
		// Three chars on one account at levels 5/40/40 — tie-break is char_id ASC.
		_, _ = pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, user_id, name, account_id, account_name, race, class, lev)
			 VALUES (9010091, 'r10_low',  'r10_low',  $1, 'r10_acct', 1, 1, 5),
			        (9010092, 'r10_top1', 'r10_top1', $1, 'r10_acct', 1, 1, 40),
			        (9010093, 'r10_top2', 'r10_top2', $1, 'r10_acct', 1, 1, 40)`, aid)
		var (
			gotAcc, gotChar, gotLev int
			gotSrv                  int16
		)
		err := pool.CallSPRow(ctx, "aion_gethighestlevelcharacterofaccount", aid).Scan(
			&gotAcc, &gotSrv, &gotChar, &gotLev)
		if err != nil {
			t.Fatalf("Scan: %v", err)
		}
		if gotChar != 9010092 {
			t.Fatalf("char_id: got %d, want 9010092 (lev=40, smaller char_id)", gotChar)
		}
		if gotLev != 40 {
			t.Fatalf("lev: got %d, want 40", gotLev)
		}
	})
}

// TestCharLifecycleE2E — the full create→list→load→login→logout→delete
// chain. This is the "smoke test" that proves a player can actually enter
// the world from a clean account. Before Round 10 this chain could not run
// because aion_DeleteChar was missing.
//
// Stages:
//
//	SETUP   build a synthetic account row in user_data via PutChar
//	CREATE  PutChar succeeds → rc=0, char_id assigned
//	LIST    GetCharIdList returns that one char_id for the account
//	LOAD    GetCharInfo / GetCharBuilder / GetCharInfoBasic all surface
//	        the character with the same name/race/class as CREATE
//	LOGIN   SetCharLoginTime stamps last_login; SetCharLocation moves char
//	LOGOUT  SetCharLogoutTime + SetCharInfo persist the dirty state
//	DELETE  SetCharDeleteTime → GetDeletedCharList → cascade-delete →
//	        DeleteChar; verify the row is physically gone.
func TestCharLifecycleE2E(t *testing.T) {
	pool, ctx, cancel := setupRound10(t)
	defer cancel()

	const (
		accountID   = 9100500
		accountName = "r10_e2e_acct"
		charName    = "r10_e2e_hero"
	)

	// -------- SETUP / CREATE -------------------------------------------------
	charID, createTime := callPutChar(t, ctx, pool, charName, accountID, accountName)
	if createTime.IsZero() {
		t.Fatalf("createTime zero")
	}
	t.Logf("CREATE: char_id=%d created=%s", charID, createTime.Format(time.RFC3339))

	// -------- LIST -----------------------------------------------------------
	rows, err := pool.CallSP(ctx, "aion_getcharidlist", accountID)
	if err != nil {
		t.Fatalf("GetCharIdList: %v", err)
	}
	listed := map[int]string{}
	for rows.Next() {
		var (
			cid int
			uid string
		)
		if err := rows.Scan(&cid, &uid); err != nil {
			rows.Close()
			t.Fatalf("scan list: %v", err)
		}
		listed[cid] = uid
	}
	rows.Close()
	if listed[charID] != charName {
		t.Fatalf("LIST: char %d (%q) not found in account list %v", charID, charName, listed)
	}
	t.Logf("LIST: %d entries, %d=%q", len(listed), charID, listed[charID])

	// -------- LOAD: GetCharInfoBasic + GetCharBuilder ------------------------
	var (
		basicAcc, basicGID, basicGRank int
		basicClass                     int16
		basicUserID                    string
	)
	if err := pool.CallSPRow(ctx, "aion_getcharinfobasic", charID).Scan(
		&basicAcc, &basicClass, &basicGID, &basicUserID, &basicGRank); err != nil {
		t.Fatalf("GetCharInfoBasic: %v", err)
	}
	if basicAcc != accountID || basicUserID != charName {
		t.Fatalf("LOAD basic mismatch: acc=%d uid=%q (want %d/%q)",
			basicAcc, basicUserID, accountID, charName)
	}

	var builder sql.NullString
	if err := pool.CallSPRow(ctx, "aion_getcharbuilder", charID).Scan(&builder); err != nil {
		t.Fatalf("GetCharBuilder: %v", err)
	}
	// builder is CHAR(1) — '0' for non-GM. We only assert it returned a
	// row; the value is not load-bearing for the E2E happy path.
	if !builder.Valid {
		t.Fatalf("LOAD: builder column NULL (char not found)")
	}

	// LOAD: full GetCharInfo_20160818 — we Scan into 145 columns, but only
	// assert the few that mirror CREATE inputs to keep the test focused.
	t.Run("LOAD GetCharInfo_20160818 surfaces CREATE values", func(t *testing.T) {
		row := pool.Inner().QueryRow(ctx,
			`SELECT user_id, race, class, world FROM aion_getcharinfo_20160818($1)`, charID)
		var (
			gotUserID    string
			gotRace      int16
			gotClass     int16
			gotWorld     int
		)
		if err := row.Scan(&gotUserID, &gotRace, &gotClass, &gotWorld); err != nil {
			t.Fatalf("GetCharInfo: %v", err)
		}
		if gotUserID != charName {
			t.Fatalf("user_id: got %q want %q", gotUserID, charName)
		}
		if gotRace != 0 {
			t.Fatalf("race: got %d want 0 (Elyos)", gotRace)
		}
		if gotClass != 1 {
			t.Fatalf("class: got %d want 1 (Warrior)", gotClass)
		}
		if gotWorld != 210020000 {
			t.Fatalf("world: got %d want 210020000 (Poeta)", gotWorld)
		}
	})
	t.Logf("LOAD: basic+builder+full GetCharInfo OK")

	// -------- LOGIN: set last_login + move char to a new world ---------------
	var loginTime time.Time
	if err := pool.CallSPRow(ctx, "aion_setcharlogintime_20120516", charID).Scan(&loginTime); err != nil {
		t.Fatalf("SetCharLoginTime: %v", err)
	}
	if loginTime.IsZero() {
		t.Fatalf("loginTime zero")
	}
	const (
		curServer  = 7777
		newWorld   = 210050000
		newX, newY = float32(2500), float32(2500)
		newZ       = float32(150)
	)
	if err := pool.CallSPExec(ctx, "aion_setcharlocation", charID, curServer, newWorld, newX, newY, newZ); err != nil {
		t.Fatalf("SetCharLocation: %v", err)
	}
	// Verify location moved.
	var gotWorld int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT world FROM user_data WHERE char_id=$1`, charID).Scan(&gotWorld); err != nil {
		t.Fatalf("read world: %v", err)
	}
	if gotWorld != newWorld {
		t.Fatalf("LOGIN world move: got %d want %d", gotWorld, newWorld)
	}
	t.Logf("LOGIN: login_time=%s world->%d", loginTime.Format(time.RFC3339), newWorld)

	// -------- LOGOUT: SetCharInfo persist + SetCharLogoutTime ----------------
	// SetCharInfo_20160818 takes 65 columns; we exercise it with the same
	// shape the world server uses on logout flush. Most fields are 0 — the
	// load-bearing one is `lev` (we bump from 1→5 to model XP gained).
	const newLev = 5
	// SetCharInfo_20160818 takes exactly 65 positional args. Layout matches
	// the SP signature in sql/schema/00044_sp_set_char_info.sql; each line
	// here is grouped by the corresponding section in the SP UPDATE list to
	// make argument-vs-column drift easy to spot in code review.
	if err := pool.CallSPExec(ctx, "aion_setcharinfo_20160818",
		charID,                                     // 1.  char_id
		1,                                          // 2.  class
		0, 0, 0,                                    // 3-5. guild_id, guild_rank, recreate_guild_time
		curServer, newWorld, 0,                     // 6-8. cur_server, world, world_map_number
		newX, newY, newZ, 0,                        // 9-12. xyz, dir
		newWorld, newX, newY, newZ, 0,              // 13-17. last_normal_world/xyz/dir
		0, int64(0),                                // 18-19. death_count, temporary_lost_exp
		newWorld, newX, newY, newZ,                 // 20-23. resurrect_world/xyz
		500, 300, 0,                                // 24-26. hp, mp, fp
		int64(1234), int64(0), int64(0),            // 27-29. exp, abyss_point, abyss_point_from_user
		newLev, 0, 0, 0,                            // 30-33. level, stigma_point, cur_title_id, cur_title_attr_id
		"", "",                                     // 34-35. guild_intro, guild_nickname
		0, int64(0),                                // 36-37. today_abyss_kill_cnt, today_abyss_point
		0, int64(0),                                // 38-39. this_week_abyss_kill_cnt, this_week_abyss_point
		0, int64(0),                                // 40-41. last_week_abyss_kill_cnt, last_week_abyss_point
		0, 0, 0,                                    // 42-44. total_abyss_kill_cnt, best_abyss_rank, is_freefly
		0, 0, 0, 0,                                 // 45-48. optionflags, accused_count, last_accuse_time, bot_point
		int64(0), int64(0),                         // 49-50. vital_point, pvp_exp
		0, 0, 0,                                    // 51-53. serial_kill_point, _duration, _penalty_skill_rank
		0,                                          // 54. enhanced_stigma_slot_cnt
		0, 0,                                       // 55-56. housing_id, fatigue_resttime_online
		int64(0),                                   // 57. next_hotspot_use_time
		0, int64(0), 0,                             // 58-60. gotcha_fever_point/_expire_time/_hit_count
		0, int64(0),                                // 61-62. last_explicit_beginner_force, absolute_exp
		0, 0,                                       // 63-64. serial_guard_point, serial_guard_last_scantime
		int64(0),                                   // 65. absolute_ap
	); err != nil {
		t.Fatalf("SetCharInfo: %v", err)
	}

	var logoutTime time.Time
	if err := pool.CallSPRow(ctx, "aion_setcharlogouttime_20120516", charID).Scan(&logoutTime); err != nil {
		t.Fatalf("SetCharLogoutTime: %v", err)
	}
	// Verify lev persisted.
	var gotLev int
	_ = pool.Inner().QueryRow(ctx,
		`SELECT lev FROM user_data WHERE char_id=$1`, charID).Scan(&gotLev)
	if gotLev != newLev {
		t.Fatalf("LOGOUT lev persist: got %d want %d", gotLev, newLev)
	}
	t.Logf("LOGOUT: logout_time=%s lev=%d persisted", logoutTime.Format(time.RFC3339), gotLev)

	// -------- DELETE: schedule purge → list → cascade → DeleteChar -----------
	pastTime := int(time.Now().Unix() - 1) // already elapsed
	if err := pool.CallSPExec(ctx, "aion_setchardeletetime", charID, pastTime); err != nil {
		t.Fatalf("SetCharDeleteTime: %v", err)
	}

	// Sweeper pulls the elapsed list.
	rows, err = pool.CallSP(ctx, "aion_getdeletedcharlist", 1, int(time.Now().Unix()))
	if err != nil {
		t.Fatalf("GetDeletedCharList: %v", err)
	}
	found := false
	for rows.Next() {
		var (
			cid, accID, gid, grank int
			uid, accName           string
		)
		_ = rows.Scan(&cid, &uid, &accID, &accName, &gid, &grank)
		if cid == charID {
			found = true
		}
	}
	rows.Close()
	if !found {
		t.Fatalf("DELETE: sweeper missed char_id %d", charID)
	}

	// Cascade — wipe items/skills/quests/buffs (all empty for this hero,
	// but the SP must accept the call without error so the sweeper can run
	// blindly). For warehouse 0 only — a real sweeper iterates all buckets.
	if err := pool.CallSPExec(ctx, "aion_deleteitembychar", charID, 0); err != nil {
		t.Fatalf("DELETE cascade DeleteItemByChar: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_deleteallskill", charID); err != nil {
		t.Fatalf("DELETE cascade DeleteAllSkill: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_deleteallquest", charID); err != nil {
		t.Fatalf("DELETE cascade DeleteAllQuest: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_deleteallabnormalstatus", charID); err != nil {
		t.Fatalf("DELETE cascade DeleteAllAbnormalStatus: %v", err)
	}

	// Final purge.
	if err := pool.CallSPExec(ctx, "aion_deletechar", charID); err != nil {
		t.Fatalf("DELETE: %v", err)
	}

	// -------- TEARDOWN VERIFICATION ------------------------------------------
	var n int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT COUNT(*) FROM user_data WHERE char_id=$1`, charID).Scan(&n); err != nil {
		t.Fatalf("verify gone: %v", err)
	}
	if n != 0 {
		t.Fatalf("TEARDOWN: char_id %d still present after DeleteChar", charID)
	}
	// And the account list is now empty.
	rows, err = pool.CallSP(ctx, "aion_getcharidlist", accountID)
	if err != nil {
		t.Fatalf("verify list empty: %v", err)
	}
	count := 0
	for rows.Next() {
		count++
	}
	rows.Close()
	if count != 0 {
		t.Fatalf("TEARDOWN: account list non-empty after delete: %d entries", count)
	}
	t.Logf("TEARDOWN OK: char_id=%d fully purged", charID)
}
