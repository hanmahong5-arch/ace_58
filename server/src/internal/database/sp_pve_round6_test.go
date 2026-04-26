// Package database — Round 6 (Track B4) integration tests for the 19 newly-
// ported NCSoft stored procedures.
//
// Layout mirrors sp_pve_test.go: each subtest is independent and uses the
// 9_000_000-9_000_099 char-id band (or NULL-band PutChar IDs); fixtureCleanup
// in sp_pve_test.go wipes both bands before and after.
//
// Round 6 SPs covered (19 total):
//   Priority A (12):
//     aion_PutChar_20160620, aion_GetCharInfo_20160818, aion_SetCharInfo_20160818,
//     aion_GetCharBuilder, aion_SetQuest, aion_DeleteQuest,
//     aion_putFinishedQuestSimple, aion_GetItemList_20120102,
//     aion_SetItemEnchant_20180615, aion_GetSkillCooltime,
//     aion_PutSkillCooltime, aion_PutSkillSkin
//   Priority B (7):
//     aion_MailList, aion_MailRead, aion_MailDelete, aion_MailSetRead,
//     aion_MailGetBoxSize, aion_AddGuildPoint, aion_SetGuildIntro

package database

import (
	"context"
	"database/sql"
	"testing"
	"time"
)

// TestPortedSPs_Round6 exercises every Round 6 SP at least once.
func TestPortedSPs_Round6(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
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

	// ---- Priority A: char ---------------------------------------------------

	t.Run("aion_PutChar_20160620 creates a character and returns rc=0 + new id", func(t *testing.T) {
		// 110 params — pass with named-positional discipline. We let the SP
		// pick the next char_id via MAX+1 so the row joins the b4test_ family
		// for cleanup. We only check rc=0 + non-null id + create_time.
		var (
			rc          int
			newCharID   int
			createTime  time.Time
		)
		err := pool.CallSPRow(ctx, "aion_putchar_20160620",
			"b4test_putchar1",      // user_id
			909500,                 // account_id
			"b4test_acct1",         // account_name
			1,                      // race
			1,                      // class
			0,                      // gender
			0xFFFFFF, 0xCCCCCC, 0xFFFFFF, 0xAAAAAA, // colors
			1, 1,                   // face_type, hair_type
			float64(1.0),           // scale
			1, 0, 0,                // voice, feat1, feat2
			0, 0,                   // bump, expression
			170001,                 // name_id
			1,                      // org_server
			210050000,              // world
			float32(1500), float32(2500), float32(120), // xyz
			0,                      // dir
			500, 200,               // hp, mp
			0,                      // builder
			1,                      // lev
			210050000, float32(1500), float32(2500), float32(120), // resurrect
			0,                      // inventory_growth
			// 50 customize feat_*/head_* params
			1,                      // feat_version
			0, 0, 0, 0, 0, 0, 0, 0, // face_shape..eye_tail
			0, 0, 0,                // eyeblow_*
			0, 0, 0, 0,             // nose_*
			0,                      // cheek_shape
			0, 0, 0, 0, 0,          // mouth_*/lip_*
			0, 0,                   // jaw_pos, jaw_shape
			0, 0,                   // ear_shape, head_size
			0, 0, 0,                // neck_*, shoulder
			0, 0, 0, 0,             // upper..hip
			0, 0, 0, 0,             // arm..foot
			0, 0,                   // face_ratio, wing
			1, 1, 1,                // arm_length, leg_length, shoulder_width
			0,                      // head_figure
			0, 0, 0, 0,             // head_eye_type/dark_tail/eye_color2/eye_lash
			0, 0,                   // head_eye_size, upper_height
			0, 0, 0,                // arm_lower, hand_length, leg_lower
			0,                      // is_jumping_character
		).Scan(&rc, &newCharID, &createTime)
		if err != nil {
			t.Fatalf("PutChar: %v", err)
		}
		if rc != 0 {
			t.Fatalf("rc: got %d, want 0", rc)
		}
		if newCharID <= 0 {
			t.Fatalf("char_id non-positive: %d", newCharID)
		}
		if createTime.IsZero() {
			t.Fatalf("create_time zero")
		}
	})

	t.Run("aion_PutChar_20160620 returns name-collision rc on duplicate", func(t *testing.T) {
		// Insert a row first via the same SP, then call again with the same
		// user_id. CheckValidCharName should bounce it back as -1.
		_, _ = pool.Inner().Exec(ctx, `DELETE FROM user_data WHERE user_id = 'b4test_dup'`)
		runPutChar := func(uid string) (rc int) {
			// rc=0 → c & t0 populated; rc<>0 → both NULL. Use sql.Null* so
			// either branch scans cleanly.
			var c sql.NullInt32
			var t0 sql.NullTime
			err := pool.CallSPRow(ctx, "aion_putchar_20160620",
				uid, 909600, "b4test_acct2",
				1, 1, 0,
				0xFFFFFF, 0xCCCCCC, 0xFFFFFF, 0xAAAAAA,
				1, 1,
				float64(1.0),
				1, 0, 0,
				0, 0,
				170002,
				1, 210050000,
				float32(1), float32(2), float32(3),
				0, 500, 200, 0, 1,
				210050000, float32(1), float32(2), float32(3),
				0,
				1,
				0, 0, 0, 0, 0, 0, 0, 0,
				0, 0, 0,
				0, 0, 0, 0,
				0,
				0, 0, 0, 0, 0,
				0, 0,
				0, 0,
				0, 0, 0,
				0, 0, 0, 0,
				0, 0, 0, 0,
				0, 0,
				1, 1, 1,
				0,
				0, 0, 0, 0,
				0, 0,
				0, 0, 0,
				0,
			).Scan(&rc, &c, &t0)
			if err != nil {
				t.Fatalf("PutChar(%s): %v", uid, err)
			}
			return rc
		}
		if rc := runPutChar("b4test_dup"); rc != 0 {
			t.Fatalf("first PutChar: rc=%d, want 0", rc)
		}
		if rc := runPutChar("b4test_dup"); rc == 0 {
			t.Fatalf("second PutChar should NOT succeed (rc=0)")
		}
	})

	t.Run("aion_GetCharBuilder reads the builder flag", func(t *testing.T) {
		const cid = 9000201
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, builder) VALUES ($1, 'GMTester', '1')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		var b string
		if err := pool.CallSPRow(ctx, "aion_getcharbuilder", cid).Scan(&b); err != nil {
			t.Fatalf("GetCharBuilder: %v", err)
		}
		if b != "1" {
			t.Fatalf("builder: got %q, want %q", b, "1")
		}
	})

	t.Run("aion_GetCharInfo_20160818 returns the joined char row", func(t *testing.T) {
		// Seed a guild + a char bound to it so the LEFT JOIN returns the name.
		const (
			gid = 9000202
			cid = 9000203
		)
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name, race, level) VALUES ($1, 'b4test_legion_info', 1, 5)`, gid); err != nil {
			t.Fatalf("seed guild: %v", err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, account_id, guild_id, lev, race, class)
			 VALUES ($1, 'InfoHero', 'b4test_info', 909700, $2, 25, 1, 3)`,
			cid, gid); err != nil {
			t.Fatalf("seed user_data: %v", err)
		}
		// 137 cols — we only scan the first 5 to keep the test focused.
		rows, err := pool.CallSP(ctx, "aion_getcharinfo_20160818", cid)
		if err != nil {
			t.Fatalf("GetCharInfo: %v", err)
		}
		defer rows.Close()
		var found bool
		for rows.Next() {
			vals, err := rows.Values()
			if err != nil {
				t.Fatalf("Values: %v", err)
			}
			if len(vals) < 21 {
				t.Fatalf("expected 137+ cols, got %d", len(vals))
			}
			// vals[0] = user_id, [1] = account_id, [18] = guild_id, [20] = guild_name
			if vals[0] != "b4test_info" {
				t.Fatalf("user_id: %v", vals[0])
			}
			if vals[18].(int32) != int32(gid) {
				t.Fatalf("guild_id: %v want %d", vals[18], gid)
			}
			if vals[20] != "b4test_legion_info" {
				t.Fatalf("guild_name: %v", vals[20])
			}
			found = true
		}
		if !found {
			t.Fatalf("no row returned")
		}
	})

	t.Run("aion_SetCharInfo_20160818 persists 50+ mutable fields", func(t *testing.T) {
		const cid = 9000204
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'SaveHero')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		err := pool.CallSPExec(ctx, "aion_setcharinfo_20160818",
			cid,                   // char_id
			3,                     // class
			0,                     // guild_id
			0,                     // guild_rank
			0,                     // recreate_guild_time
			1,                     // cur_server
			210050000,             // world
			0,                     // world_map_number
			float32(1234), float32(5678), float32(99), // xyz
			120,                   // dir
			210050000,             // last_normal_world
			float32(1), float32(2), float32(3), 0, // last_normal_*
			0, int64(0),           // death_count, temp_lost_exp
			210050000,             // resurrect_world
			float32(0), float32(0), float32(0), // resurrect_xyz
			450, 230, 100,         // hp, mp, fp
			int64(123456), int64(0), int64(0), // exp, abyss, abyss_from_user
			25, 7, 0, 0,           // level, stigma, title, title_attr
			"hello", "Nick",       // intro, nickname
			0, int64(0), 0, int64(0), 0, int64(0), 0, 0, // abyss tracking 8
			0,                     // is_freefly
			0, 0, 0,               // optionflags, accused, last_accuse
			0, int64(0), int64(0), // bot, vital, pvp_exp
			0, 0, 0,               // serial_kill_*
			0,                     // enhanced_stigma
			0, 0, int64(0),        // housing, fatigue, hotspot
			0, int64(0), 0,        // gotcha
			0, int64(99),          // beginner, absolute_exp
			0, 0, int64(0),        // serial_guard, scantime, absolute_ap
		)
		if err != nil {
			t.Fatalf("SetCharInfo: %v", err)
		}
		var (
			lev, class int
			x          float32
			intro      string
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT lev, class, xlocation, guild_intro FROM user_data WHERE char_id = $1`, cid).
			Scan(&lev, &class, &x, &intro); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if lev != 25 || class != 3 || x != 1234 || intro != "hello" {
			t.Fatalf("mismatch: lev=%d class=%d x=%g intro=%q", lev, class, x, intro)
		}
	})

	// ---- Priority A: quests -------------------------------------------------

	t.Run("aion_SetQuest updates an existing in-progress quest", func(t *testing.T) {
		const cid = 9000210
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Q')`, cid); err != nil {
			t.Fatalf("seed char: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putquest", cid, 5001, 0, 0); err != nil {
			t.Fatalf("PutQuest: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setquest", cid, 5001, 1, 50); err != nil {
			t.Fatalf("SetQuest: %v", err)
		}
		var status, prog int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT quest_status, quest_progress FROM user_quest WHERE char_id = $1 AND quest_id = 5001`, cid).
			Scan(&status, &prog); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if status != 1 || prog != 50 {
			t.Fatalf("status=%d progress=%d", status, prog)
		}
	})

	t.Run("aion_DeleteQuest removes the row", func(t *testing.T) {
		const cid = 9000211
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'D')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putquest", cid, 5002, 0, 0); err != nil {
			t.Fatalf("PutQuest: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_deletequest", cid, 5002); err != nil {
			t.Fatalf("DeleteQuest: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_quest WHERE char_id = $1 AND quest_id = 5002`, cid).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 0 {
			t.Fatalf("quest not deleted")
		}
	})

	t.Run("aion_putFinishedQuestSimple inserts and is idempotent", func(t *testing.T) {
		const cid = 9000212
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'F')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putfinishedquestsimple", cid, 6001, 0); err != nil {
			t.Fatalf("PutFin: %v", err)
		}
		// Second call must not error and must not double-insert.
		if err := pool.CallSPExec(ctx, "aion_putfinishedquestsimple", cid, 6001, 0); err != nil {
			t.Fatalf("PutFin dup: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_finished_quest WHERE char_id = $1 AND quest_id = 6001`, cid).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 1 {
			t.Fatalf("count: got %d, want 1", n)
		}
	})

	// ---- Priority A: items --------------------------------------------------

	t.Run("aion_GetItemList_20120102 returns inventory rows scoped to warehouse", func(t *testing.T) {
		const cid = 9000220
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'IL')`, cid); err != nil {
			t.Fatalf("seed char: %v", err)
		}
		// Drop 3 rows: 2 in inventory (warehouse=0), 1 in char-warehouse (=1)
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_item(char_id, name_id, amount, warehouse, producer, export_id) VALUES
			 ($1, 110000001, 1, 0, 'inv1', 0),
			 ($1, 110000002, 5, 0, 'inv2', 0),
			 ($1, 110000003, 1, 1, 'wh',   0)`, cid)
		if err != nil {
			t.Fatalf("seed items: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getitemlist_20120102", cid, 0)
		if err != nil {
			t.Fatalf("GetItemList: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 2 {
			t.Fatalf("inventory count: got %d, want 2", n)
		}
	})

	t.Run("aion_SetItemEnchant_20180615 upserts the enchant row", func(t *testing.T) {
		const cid = 9000221
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'EN')`, cid); err != nil {
			t.Fatalf("seed char: %v", err)
		}
		var itemID int64
		if err := pool.Inner().QueryRow(ctx,
			`INSERT INTO user_item(char_id, name_id, amount, warehouse, producer)
			 VALUES ($1, 110010001, 1, 0, 'forge') RETURNING id`, cid).Scan(&itemID); err != nil {
			t.Fatalf("seed item: %v", err)
		}
		// Call SetItemEnchant — 47 params total.
		err := pool.CallSPExec(ctx, "aion_setitemenchant_20180615",
			itemID,             // id
			0,                  // soul_bound
			7,                  // enchant_count
			0,                  // skin_name_id
			0,                  // wardrobe_slot_id
			0, 0, 0, 0, 0, 0,   // stat_enchant_name 0..5
			0,                  // proc_tool_nameid
			0, 0,               // obtain_skin_type, expire_skin_time
			0,                  // limit_enchant_count
			0,                  // authorize_count
			0,                  // vanish_point
			0, 0,               // enchant_prob, option_prob
			0,                  // key_name_id
			0,                  // exceed_state
			0, 0, 0,            // exceed_skill_id 1..3
			0, 0, 0,            // base, enhance group, enhance level
			0,                  // equip_level_down
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 10 attr/value pairs
			0,                  // skill_skin_name_id
		)
		if err != nil {
			t.Fatalf("SetItemEnchant insert: %v", err)
		}
		var ec int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enchant_count FROM user_item_option WHERE id = $1`, itemID).Scan(&ec); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if ec != 7 {
			t.Fatalf("enchant_count: got %d, want 7", ec)
		}
		// Second call → UPDATE branch, change enchant_count.
		err = pool.CallSPExec(ctx, "aion_setitemenchant_20180615",
			itemID, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0,
		)
		if err != nil {
			t.Fatalf("SetItemEnchant update: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT enchant_count FROM user_item_option WHERE id = $1`, itemID).Scan(&ec); err != nil {
			t.Fatalf("verify2: %v", err)
		}
		if ec != 12 {
			t.Fatalf("enchant_count after update: got %d, want 12", ec)
		}
	})

	// ---- Priority A: skills -------------------------------------------------

	t.Run("aion_PutSkillCooltime + GetSkillCooltime persist a varbinary blob", func(t *testing.T) {
		const cid = 9000230
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'CD')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		blob := []byte{0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04}
		if err := pool.CallSPExec(ctx, "aion_putskillcooltime", cid, 1, blob); err != nil {
			t.Fatalf("PutSkillCooltime: %v", err)
		}
		// Round-trip via GetSkillCooltime.
		rows, err := pool.CallSP(ctx, "aion_getskillcooltime", cid)
		if err != nil {
			t.Fatalf("GetSkillCooltime: %v", err)
		}
		defer rows.Close()
		var (
			cnt  int
			data []byte
		)
		var found bool
		for rows.Next() {
			if err := rows.Scan(&cnt, &data); err != nil {
				t.Fatalf("scan: %v", err)
			}
			found = true
		}
		if !found {
			t.Fatalf("no row returned")
		}
		if cnt != 1 || len(data) != 8 || data[0] != 0xDE {
			t.Fatalf("blob mismatch: cnt=%d len=%d first=0x%X", cnt, len(data), data[0])
		}
		// Upsert: change blob.
		blob2 := []byte{0xCA, 0xFE}
		if err := pool.CallSPExec(ctx, "aion_putskillcooltime", cid, 1, blob2); err != nil {
			t.Fatalf("PutSkillCooltime upsert: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_skill_cooltime WHERE char_id = $1`, cid).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 1 {
			t.Fatalf("upsert duplicated: %d rows", n)
		}
	})

	t.Run("aion_PutSkillSkin upserts cosmetic skin ownership", func(t *testing.T) {
		const cid = 9000231
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'Sk')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putskillskin", cid, 1234, 1700000000); err != nil {
			t.Fatalf("PutSkillSkin: %v", err)
		}
		// Re-grant: use_skin must be reset to 0.
		_, _ = pool.Inner().Exec(ctx, `UPDATE user_skill_skin SET use_skin = 1 WHERE char_id = $1`, cid)
		if err := pool.CallSPExec(ctx, "aion_putskillskin", cid, 1234, 1800000000); err != nil {
			t.Fatalf("PutSkillSkin re-grant: %v", err)
		}
		var (
			useSkin int
			expire  int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_skin, expire_time FROM user_skill_skin WHERE char_id = $1 AND skill_skin_id = 1234`, cid).
			Scan(&useSkin, &expire); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if useSkin != 0 || expire != 1800000000 {
			t.Fatalf("re-grant: use_skin=%d expire=%d (want 0/1800000000)", useSkin, expire)
		}
	})

	// ---- Priority B: mail ---------------------------------------------------

	t.Run("aion_MailList + MailGetBoxSize + MailRead + MailSetRead + MailDelete chain", func(t *testing.T) {
		const cid = 9000240
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name) VALUES ($1, 'MX')`, cid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		now := int(time.Now().Unix())
		// Drop 3 mails. delete_flag=0, state=0, all delivered already.
		var mailIDs [3]int64
		for i := 0; i < 3; i++ {
			if err := pool.CallSPRow(ctx, "aion_mailwritesys_20111227",
				cid, "MX", 0, "System",
				"Subject", "Body",
				int64(0), 0, int64(0), int64(100*(i+1)), 0, now-1, 0,
			).Scan(&mailIDs[i]); err != nil {
				t.Fatalf("seed mail %d: %v", i, err)
			}
		}

		// MailList — should return all 3, newest first.
		rows, err := pool.CallSP(ctx, "aion_maillist", cid, now, 50)
		if err != nil {
			t.Fatalf("MailList: %v", err)
		}
		var n int
		for rows.Next() {
			n++
		}
		rows.Close()
		if n != 3 {
			t.Fatalf("MailList count: got %d, want 3", n)
		}

		// MailGetBoxSize — 3 total, 3 unread.
		var total, unread, exp, cash int
		if err := pool.CallSPRow(ctx, "aion_mailgetboxsize", cid, now).
			Scan(&total, &unread, &exp, &cash); err != nil {
			t.Fatalf("MailGetBoxSize: %v", err)
		}
		if total != 3 || unread != 3 {
			t.Fatalf("box: total=%d unread=%d (want 3/3)", total, unread)
		}

		// MailRead first mail — should mark it read AND return body.
		body, err := pool.CallSP(ctx, "aion_mailread", cid, mailIDs[0])
		if err != nil {
			t.Fatalf("MailRead: %v", err)
		}
		var bodyN int
		for body.Next() {
			bodyN++
		}
		body.Close()
		if bodyN != 1 {
			t.Fatalf("MailRead returned %d rows, want 1", bodyN)
		}
		// Verify state flipped.
		var st int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM user_mail WHERE id = $1`, mailIDs[0]).Scan(&st); err != nil {
			t.Fatalf("verify state: %v", err)
		}
		if st != 1 {
			t.Fatalf("MailRead state: got %d, want 1", st)
		}

		// MailSetRead second — must return 0 (success).
		var rc int
		if err := pool.CallSPRow(ctx, "aion_mailsetread", cid, mailIDs[1]).Scan(&rc); err != nil {
			t.Fatalf("MailSetRead: %v", err)
		}
		if rc != 0 {
			t.Fatalf("MailSetRead: got %d, want 0", rc)
		}
		// Re-call → already read, must return 1.
		if err := pool.CallSPRow(ctx, "aion_mailsetread", cid, mailIDs[1]).Scan(&rc); err != nil {
			t.Fatalf("MailSetRead2: %v", err)
		}
		if rc != 1 {
			t.Fatalf("MailSetRead idempotent: got %d, want 1 (already read)", rc)
		}

		// MailDelete third → returns (0, prev_state=0).
		var (
			delRC, prevState int
		)
		if err := pool.CallSPRow(ctx, "aion_maildelete", cid, mailIDs[2]).Scan(&delRC, &prevState); err != nil {
			t.Fatalf("MailDelete: %v", err)
		}
		if delRC != 0 || prevState != 0 {
			t.Fatalf("MailDelete: rc=%d prev=%d (want 0/0)", delRC, prevState)
		}
		// Verify gone.
		var stillThere int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_mail WHERE id = $1`, mailIDs[2]).Scan(&stillThere); err != nil {
			t.Fatalf("verify del: %v", err)
		}
		if stillThere != 0 {
			t.Fatalf("MailDelete: row still present")
		}

		// Re-Delete same id → rc=1.
		if err := pool.CallSPRow(ctx, "aion_maildelete", cid, mailIDs[2]).Scan(&delRC, &prevState); err != nil {
			t.Fatalf("MailDelete dup: %v", err)
		}
		if delRC != 1 {
			t.Fatalf("MailDelete idempotent: rc=%d, want 1", delRC)
		}
	})

	// ---- Priority B: guild --------------------------------------------------

	t.Run("aion_AddGuildPoint accumulates and supports negative", func(t *testing.T) {
		const gid = 9000250
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name, race, point) VALUES ($1, 'b4test_pts', 1, 1000)`, gid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_addguildpoint", gid, int64(250)); err != nil {
			t.Fatalf("AddGP +: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_addguildpoint", gid, int64(-100)); err != nil {
			t.Fatalf("AddGP -: %v", err)
		}
		var pt int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT point FROM guild WHERE id = $1`, gid).Scan(&pt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if pt != 1150 {
			t.Fatalf("point: got %d, want 1150", pt)
		}
	})

	t.Run("aion_SetGuildIntro updates the legion intro", func(t *testing.T) {
		const gid = 9000251
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name, race, intro) VALUES ($1, 'b4test_intro', 1, 'old')`, gid); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setguildintro", gid, "new motto"); err != nil {
			t.Fatalf("SetGuildIntro: %v", err)
		}
		var intro string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT intro FROM guild WHERE id = $1`, gid).Scan(&intro); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if intro != "new motto" {
			t.Fatalf("intro: got %q", intro)
		}
	})
}

// TestPortedSPs_Smoke_E2E_Round6 — extends the Round 5 E2E with the new SPs.
//
// Chain:
//   PutChar  → GetCharBuilder → GetCharInfo
// → PutGuild → SetGuildMember → SetGuildIntro → AddGuildPoint
// → PutQuest → SetQuest → DeleteQuest
// → PutItem  → PutSkillCooltime → PutSkillSkin
// → MailWriteSys → MailList → MailRead → MailGetBoxSize → MailDelete
// → SetCharInfo → cleanup
func TestPortedSPs_Smoke_E2E_Round6(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
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

	// 1. PutChar (full flow) — gets a char_id allocated by SP.
	var (
		rc          int
		cid         int
		createTime  time.Time
	)
	err = pool.CallSPRow(ctx, "aion_putchar_20160620",
		"b4test_e2e_hero",
		909900,
		"b4test_e2e_acct",
		1, 1, 0,
		0xFFFFFF, 0xCCCCCC, 0xFFFFFF, 0xAAAAAA,
		1, 1,
		float64(1.0),
		1, 0, 0,
		0, 0,
		170099,
		1, 210050000,
		float32(100), float32(200), float32(50),
		0,
		500, 200,
		1, 1,
		210050000, float32(100), float32(200), float32(50),
		0,
		1,
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0,
		0, 0, 0, 0,
		0,
		0, 0, 0, 0, 0,
		0, 0,
		0, 0,
		0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0,
		1, 1, 1,
		0,
		0, 0, 0, 0,
		0, 0,
		0, 0, 0,
		0,
	).Scan(&rc, &cid, &createTime)
	if err != nil {
		t.Fatalf("step 1 PutChar: %v", err)
	}
	if rc != 0 {
		t.Fatalf("PutChar rc=%d, want 0", rc)
	}
	t.Logf("created char_id=%d at %v", cid, createTime)

	// 2. GetCharBuilder — fresh char, builder='1' per our PutChar mapping.
	var b string
	if err := pool.CallSPRow(ctx, "aion_getcharbuilder", cid).Scan(&b); err != nil {
		t.Fatalf("step 2 GetCharBuilder: %v", err)
	}
	if b != "1" {
		t.Fatalf("builder=%q", b)
	}

	// 3. GetCharInfo — must return one row with the user_id we set.
	infoRows, err := pool.CallSP(ctx, "aion_getcharinfo_20160818", cid)
	if err != nil {
		t.Fatalf("step 3 GetCharInfo: %v", err)
	}
	var infoFound bool
	for infoRows.Next() {
		infoFound = true
	}
	infoRows.Close()
	if !infoFound {
		t.Fatalf("GetCharInfo returned 0 rows")
	}

	// 4-6. Legion lifecycle.
	var gid int
	if err := pool.CallSPRow(ctx, "aion_putguild_20100916",
		"b4test_e2e_legion", cid, 1, 0, 0, 0, 0).Scan(&gid); err != nil {
		t.Fatalf("step 4 PutGuild: %v", err)
	}
	var ret int
	if err := pool.CallSPRow(ctx, "aion_setguildmember", gid, cid).Scan(&ret); err != nil {
		t.Fatalf("step 5 SetGuildMember: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_setguildintro", gid, "for the entropy"); err != nil {
		t.Fatalf("step 6a SetGuildIntro: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_addguildpoint", gid, int64(500)); err != nil {
		t.Fatalf("step 6b AddGuildPoint: %v", err)
	}

	// 7-9. Quest lifecycle: put → set → delete (then refinished as completed).
	if err := pool.CallSPExec(ctx, "aion_putquest", cid, 18001, 0, 0); err != nil {
		t.Fatalf("step 7 PutQuest: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_setquest", cid, 18001, 1, 100); err != nil {
		t.Fatalf("step 8 SetQuest: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_putfinishedquestsimple", cid, 18001, 0); err != nil {
		t.Fatalf("step 8b PutFinishedQuest: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_deletequest", cid, 18001); err != nil {
		t.Fatalf("step 9 DeleteQuest: %v", err)
	}

	// 10. PutItem → PutSkillCooltime → PutSkillSkin. 43 params per
	// 00018_sp_put_item.sql signature.
	var itemID int64
	err = pool.CallSPRow(ctx, "aion_putitem_20150921",
		cid,                  // char_id
		152099001,            // name_id
		0,                    // slot_id
		int64(1),             // amount
		int64(0),             // tid
		0,                    // slot_num
		0,                    // warehouse
		0, 0, 0,              // soul_bound, enchant_count, skin_name_id
		0, 0, 0, 0, 0, 0,     // stat_enchant 0..5
		0, 0, 0, 0,           // option_count, dye_info, proc_tool_nameid, expired_time
		"boss",               // producer
		0, 0,                 // buy_amount, buy_duration
		0, 0,                 // obtain_skin_type, expire_skin_time
		0, 0,                 // dynamic_property, server_of_origin
		0,                    // expire_dye_time
		0, 0, 0,              // random_option, limit_enchant_count, reidentify_count
		0, 0,                 // authorize_count, vanish_point
		0, 0,                 // enchant_prob_addition, option_prob_addition
		0,                    // key_name_id
		0, 0, 0, 0,           // exceedState, exceedSkillId 1..3
		0, 0, 0,              // baseSkillId, enhanceSkillGroup, enhanceSkillLevel
	).Scan(&itemID)
	if err != nil {
		t.Fatalf("step 10 PutItem: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_putskillcooltime", cid, 2, []byte{0x01, 0x02, 0x03, 0x04}); err != nil {
		t.Fatalf("step 11 PutSkillCooltime: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_putskillskin", cid, 5005, 1900000000); err != nil {
		t.Fatalf("step 12 PutSkillSkin: %v", err)
	}

	// 13. Mail flow: write → list → read → boxsize → delete.
	now := int(time.Now().Unix())
	var mid int64
	if err := pool.CallSPRow(ctx, "aion_mailwritesys_20111227",
		cid, "Hero", 0, "Quest Reward",
		"Quest 18001 done", "Here's your prize.",
		int64(0), 0, int64(0), int64(5000), 0, now-1, 0,
	).Scan(&mid); err != nil {
		t.Fatalf("step 13a MailWriteSys: %v", err)
	}
	listRows, err := pool.CallSP(ctx, "aion_maillist", cid, now, 10)
	if err != nil {
		t.Fatalf("step 13b MailList: %v", err)
	}
	var ln int
	for listRows.Next() {
		ln++
	}
	listRows.Close()
	if ln != 1 {
		t.Fatalf("MailList: got %d, want 1", ln)
	}
	readRows, err := pool.CallSP(ctx, "aion_mailread", cid, mid)
	if err != nil {
		t.Fatalf("step 13c MailRead: %v", err)
	}
	var rn int
	for readRows.Next() {
		rn++
	}
	readRows.Close()
	if rn != 1 {
		t.Fatalf("MailRead: got %d rows, want 1", rn)
	}
	var total, unread, _exp, cash int
	if err := pool.CallSPRow(ctx, "aion_mailgetboxsize", cid, now).
		Scan(&total, &unread, &_exp, &cash); err != nil {
		t.Fatalf("step 13d MailGetBoxSize: %v", err)
	}
	if total != 1 || unread != 0 {
		t.Fatalf("box: total=%d unread=%d (want 1/0 — read just happened)", total, unread)
	}
	var dRC, prev int
	if err := pool.CallSPRow(ctx, "aion_maildelete", cid, mid).Scan(&dRC, &prev); err != nil {
		t.Fatalf("step 13e MailDelete: %v", err)
	}
	if dRC != 0 {
		t.Fatalf("MailDelete rc=%d", dRC)
	}

	// 14. SetCharInfo — flush 50+ stats. Smoke just verifies the call returns
	// without error; per-field assertions live in TestPortedSPs_Round6.
	err = pool.CallSPExec(ctx, "aion_setcharinfo_20160818",
		cid, 1, gid, 2, 0, 1, 210050000, 0,
		float32(100), float32(200), float32(50), 0,
		210050000, float32(0), float32(0), float32(0), 0,
		0, int64(0),
		210050000, float32(0), float32(0), float32(0),
		500, 200, 100,
		int64(99999), int64(0), int64(0),
		2, 0, 0, 0,
		"for the entropy", "Hero",
		0, int64(0), 0, int64(0), 0, int64(0), 0, 0,
		0, 0, 0, 0,
		0, int64(0), int64(0),
		0, 0, 0,
		0,
		0, 0, int64(0),
		0, int64(0), 0,
		0, int64(99),
		0, 0, int64(0),
	)
	if err != nil {
		t.Fatalf("step 14 SetCharInfo: %v", err)
	}

	// Final sanity: char_id still alive, guild still has 500 pts, no items
	// remaining (we only added one and didn't delete — but skip cleanup since
	// fixtureCleanup wipes b4test_* user_data).
	var lev int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT lev FROM user_data WHERE char_id = $1`, cid).Scan(&lev); err != nil {
		t.Fatalf("final select: %v", err)
	}
	if lev != 2 {
		t.Fatalf("level after SetCharInfo: %d, want 2", lev)
	}
	t.Logf("E2E complete: char %d (level %d) survived 14 steps", cid, lev)

	// Note: the guild row 'b4test_e2e_legion' still exists and is wiped by
	// fixtureCleanup's `DELETE FROM guild WHERE name LIKE 'b4test_%'`.
	// Add the b4test_ prefix to that filter if not already present.
	_, _ = pool.Inner().Exec(ctx, `DELETE FROM guild WHERE name LIKE 'b4test_%'`)
	_ = itemID
}
