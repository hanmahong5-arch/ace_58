// Package database — Round 8 (Track B6) integration tests for the 21 newly-
// ported NCSoft social/housing stored procedures.
//
// Layout follows sp_pve_test.go / sp_pve_round{6,7}_test.go: every subtest is
// independent and reaches into the well-known cleanup bands so concurrent
// failures cannot leak fixtures.
//
// Round 8 SPs covered (21 total):
//   Housing (6):
//     aion_PutHouseInstant, aion_GetHouseInstant,
//     aion_PutHouseObject, aion_GetHouseObjectInstant, aion_SetHouseObject,
//     aion_CheckHousingObjectCount
//   Pet (5):
//     aion_PutPetNew2, aion_GetPetListNew2, aion_RemovePet,
//     aion_SetPetNew, aion_SetPetExtra
//   Faction friendship (3):
//     aion_PutFactionFriendship, aion_GetFactionFriendshipList,
//     aion_DeleteFactionFriendship
//   Block list (4):
//     aion_AddBlock, aion_RemoveBlock, aion_GetBlock, aion_GetBlockIdList
//   Sticker / app (2):
//     aion_PutCanMakeSticker_20131202, aion_GetCanMakeSticker
//   Guild nickname (1):
//     aion_SetGuildMemberNickName
//
// Cleanup bands additional to fixtureCleanup() in sp_pve_test.go:
//   - char_id 9_000_400..9_000_499                (round-8 char band)
//   - houseobject.owner_id BETWEEN 9000400 AND 9000499
//   - house_instant.id     BETWEEN 9000400 AND 9000499
//   - user_pet.char_id     BETWEEN 9000400 AND 9000499
//   - user_block.char_id   BETWEEN 9000400 AND 9000499
//   - user_faction_friendship.char_id BETWEEN 9000400 AND 9000499
//   - user_app_installation.char_id   BETWEEN 9000400 AND 9000499

package database

import (
	"context"
	"testing"
	"time"
)

// round8Cleanup wipes round-8-specific fixtures.  Called before AND after each
// test so fail-stops never leave state behind.
func round8Cleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, stmt := range []string{
		`DELETE FROM user_pet                 WHERE char_id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM user_block               WHERE char_id BETWEEN 9000400 AND 9000499 OR block_id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM user_faction_friendship  WHERE char_id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM user_app_installation    WHERE char_id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM houseobject              WHERE owner_id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM house_instant            WHERE id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM user_data                WHERE char_id BETWEEN 9000400 AND 9000499`,
		`DELETE FROM guild                    WHERE id BETWEEN 9000400 AND 9000499 OR name LIKE 'b6test_%'`,
	} {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("round8Cleanup %q: %v", stmt, err)
		}
	}
}

// setupRound8 boots PG, runs migrations, opens a pool, and registers BOTH the
// sp_pve_test.go fixtureCleanup AND round8Cleanup so combined fixtures wipe
// cleanly.
func setupRound8(t *testing.T) (*Pool, context.Context, context.CancelFunc) {
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

	round8Cleanup(t, ctx, pool)
	t.Cleanup(func() { round8Cleanup(t, context.Background(), pool) })
	return pool, ctx, cancel
}

// seedRound8Char inserts a minimal user_data row at char_id (in the 9000400 band).
func seedRound8Char(t *testing.T, ctx context.Context, p *Pool, charID int, name string) {
	t.Helper()
	_, err := p.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)
		 ON CONFLICT (char_id) DO NOTHING`,
		charID, name, "b6test_"+name)
	if err != nil {
		t.Fatalf("seedRound8Char: %v", err)
	}
}

// TestPortedSPs_Round8 — independent per-SP tests.
func TestPortedSPs_Round8(t *testing.T) {
	pool, ctx, _ := setupRound8(t)

	// =================================================================
	// Housing (6)
	// =================================================================

	t.Run("aion_PutHouseInstant inserts a fresh row", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000401, "Owner1")
		if err := pool.CallSPExec(ctx, "aion_puthouseinstant",
			9000401, int16(2), int16(1), 0, 0); err != nil {
			t.Fatalf("call: %v", err)
		}
		var st int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM house_instant WHERE id=9000401`).Scan(&st); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if st != 2 {
			t.Fatalf("state: got %d, want 2", st)
		}
	})

	t.Run("aion_GetHouseInstant joins user_data and returns owner user_id", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000402, "Owner2")
		if err := pool.CallSPExec(ctx, "aion_puthouseinstant",
			9000402, int16(3), int16(0), 7, 8); err != nil {
			t.Fatalf("seed instant: %v", err)
		}
		var (
			st, perm     int16
			inwall, infl int
			uid          string
		)
		if err := pool.CallSPRow(ctx, "aion_gethouseinstant", 9000402).
			Scan(&st, &perm, &inwall, &infl, &uid); err != nil {
			t.Fatalf("call: %v", err)
		}
		if st != 3 || perm != 0 || inwall != 7 || infl != 8 || uid != "b6test_Owner2" {
			t.Fatalf("got st=%d perm=%d inwall=%d infl=%d uid=%q", st, perm, inwall, infl, uid)
		}
	})

	t.Run("aion_PutHouseObject returns BIGSERIAL id; CheckHousingObjectCount tracks max", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000403, "Decorator")
		var id1, id2 int64
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			55501, int16(1), 9000403, int16(1), int16(1), 99999).Scan(&id1); err != nil {
			t.Fatalf("first: %v", err)
		}
		if id1 <= 0 {
			t.Fatalf("first: id=%d", id1)
		}
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			55502, int16(1), 9000403, int16(1), int16(1), 99999).Scan(&id2); err != nil {
			t.Fatalf("second: %v", err)
		}
		if id2 <= id1 {
			t.Fatalf("monotonic: id1=%d id2=%d", id1, id2)
		}
		var maxID int64
		if err := pool.CallSPRow(ctx, "aion_checkhousingobjectcount").Scan(&maxID); err != nil {
			t.Fatalf("count: %v", err)
		}
		if maxID < id2 {
			t.Fatalf("checkcount: max=%d, want >=%d", maxID, id2)
		}
	})

	t.Run("aion_GetHouseObjectInstant excludes state=0 and other owners", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000404, "ListOwner")
		seedRound8Char(t, ctx, pool, 9000405, "OtherOwn")
		// 2 active for 9000404, 1 inactive (state=0), 1 belonging to 9000405.
		var idActive1, idActive2, idInactive, idOther int64
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			60001, int16(2), 9000404, int16(1), int16(1), 0).Scan(&idActive1); err != nil {
			t.Fatalf("a1: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			60002, int16(2), 9000404, int16(1), int16(1), 0).Scan(&idActive2); err != nil {
			t.Fatalf("a2: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			60003, int16(2), 9000404, int16(1), int16(0), 0).Scan(&idInactive); err != nil {
			t.Fatalf("ina: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			60004, int16(2), 9000405, int16(1), int16(1), 0).Scan(&idOther); err != nil {
			t.Fatalf("oth: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_gethouseobjectinstant", 9000404)
		if err != nil {
			t.Fatalf("call: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 2 {
			t.Fatalf("rows: got %d, want 2 (only active for owner 9000404)", n)
		}
	})

	t.Run("aion_SetHouseObject overwrites all mutable columns", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000406, "Mover")
		var id int64
		if err := pool.CallSPRow(ctx, "aion_puthouseobject",
			70001, int16(1), 9000406, int16(1), int16(1), 0).Scan(&id); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_sethouseobject",
			id, 70099, int16(2), 9000406, int16(1), int16(1), 12345, 7,
			110, float32(100.5), float32(200.5), float32(50.0), int16(180),
			0xAA55, 0); err != nil {
			t.Fatalf("set: %v", err)
		}
		var (
			nameid                 int
			otype, st, dir         int16
			useCount, world        int
			x, y, z                float32
			dye                    int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT object_nameid, object_type, state, dir, general_use_count,
			        world, xlocation, ylocation, zlocation, dye_info
			   FROM houseobject WHERE id=$1`, id).
			Scan(&nameid, &otype, &st, &dir, &useCount, &world, &x, &y, &z, &dye); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if nameid != 70099 || world != 110 || dir != 180 || useCount != 7 || dye != 0xAA55 {
			t.Fatalf("set mismatch: nameid=%d world=%d dir=%d cnt=%d dye=%x",
				nameid, world, dir, useCount, dye)
		}
	})

	// =================================================================
	// Pet (5)
	// =================================================================

	t.Run("aion_PutPetNew2 returns id and persists row; GetPetListNew2 reads it back", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000410, "PetOwn1")
		var id int64
		if err := pool.CallSPRow(ctx, "aion_putpetnew2",
			"Sparky", []byte{0xDE, 0xAD, 0xBE, 0xEF},
			9000410, 555001, int16(1),
			int64(100), int64(101), int64(102), int64(103),
			int64(200), int64(201), int64(202), int64(203),
			4, 1700000000).Scan(&id); err != nil {
			t.Fatalf("put: %v", err)
		}
		if id <= 0 {
			t.Fatalf("put id=%d", id)
		}
		rows, err := pool.CallSP(ctx, "aion_getpetlistnew2", 9000410)
		if err != nil {
			t.Fatalf("list: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 1 {
			t.Fatalf("list: got %d rows, want 1", n)
		}
	})

	t.Run("aion_SetPetNew updates by name_id+char_id", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000411, "PetOwn2")
		var id int64
		if err := pool.CallSPRow(ctx, "aion_putpetnew2",
			"Old", []byte{}, 9000411, 555002, int16(1),
			int64(1), int64(0), int64(0), int64(0),
			int64(2), int64(0), int64(0), int64(0),
			0, 1700000000).Scan(&id); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setpetnew",
			int64(555002), 9000411, int16(7), 1800000000,
			int64(11), int64(12), int64(13), int64(14),
			int64(21), int64(22), int64(23), int64(24)); err != nil {
			t.Fatalf("set: %v", err)
		}
		var slot int16
		var fd1, fd2ex3 int64
		var exp int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT slot_id, function_data1, function_data2_ex3, expired_time
			   FROM user_pet WHERE id=$1`, id).Scan(&slot, &fd1, &fd2ex3, &exp); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if slot != 7 || fd1 != 11 || fd2ex3 != 24 || exp != 1800000000 {
			t.Fatalf("set: slot=%d fd1=%d fd2ex3=%d exp=%d", slot, fd1, fd2ex3, exp)
		}
	})

	t.Run("aion_SetPetExtra updates name+visual by id+char_id", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000412, "PetOwn3")
		var id int64
		if err := pool.CallSPRow(ctx, "aion_putpetnew2",
			"OrigName", []byte{0x01}, 9000412, 555003, int16(1),
			int64(0), int64(0), int64(0), int64(0),
			int64(0), int64(0), int64(0), int64(0),
			1, 0).Scan(&id); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setpetextra",
			id, 9000412, "Renamed", []byte{0xFF, 0xEE}); err != nil {
			t.Fatalf("set: %v", err)
		}
		var name string
		var vd []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT name, visual_data FROM user_pet WHERE id=$1`, id).Scan(&name, &vd); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if name != "Renamed" || len(vd) != 2 || vd[0] != 0xFF || vd[1] != 0xEE {
			t.Fatalf("setextra: name=%q vd=%v", name, vd)
		}
	})

	t.Run("aion_RemovePet deletes by name_id+char_id only", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000413, "PetOwn4")
		seedRound8Char(t, ctx, pool, 9000414, "PetOwn5")
		// Same name_id 555010, two different chars.
		var idA, idB int64
		if err := pool.CallSPRow(ctx, "aion_putpetnew2",
			"P", []byte{}, 9000413, 555010, int16(1),
			int64(0), int64(0), int64(0), int64(0),
			int64(0), int64(0), int64(0), int64(0),
			0, 0).Scan(&idA); err != nil {
			t.Fatalf("seedA: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_putpetnew2",
			"Q", []byte{}, 9000414, 555010, int16(1),
			int64(0), int64(0), int64(0), int64(0),
			int64(0), int64(0), int64(0), int64(0),
			0, 0).Scan(&idB); err != nil {
			t.Fatalf("seedB: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_removepet", int64(555010), 9000413); err != nil {
			t.Fatalf("remove: %v", err)
		}
		var nA, nB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_pet WHERE id=$1`, idA).Scan(&nA); err != nil {
			t.Fatalf("vA: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_pet WHERE id=$1`, idB).Scan(&nB); err != nil {
			t.Fatalf("vB: %v", err)
		}
		if nA != 0 {
			t.Fatalf("removepet: A still present")
		}
		if nB != 1 {
			t.Fatalf("removepet: B was wrongly deleted")
		}
	})

	// =================================================================
	// Faction friendship (3)
	// =================================================================

	t.Run("aion_PutFactionFriendship inserts then upserts", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000420, "Diplomat")
		if err := pool.CallSPExec(ctx, "aion_putfactionfriendship",
			9000420, int16(11), 100, 1700000000); err != nil {
			t.Fatalf("insert: %v", err)
		}
		// Duplicate (char,faction) → UPDATE.
		if err := pool.CallSPExec(ctx, "aion_putfactionfriendship",
			9000420, int16(11), 999, 1800000000); err != nil {
			t.Fatalf("update: %v", err)
		}
		var fr, jt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT friendship, jointime FROM user_faction_friendship
			  WHERE char_id=9000420 AND faction_id=11`).Scan(&fr, &jt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if fr != 999 || jt != 1800000000 {
			t.Fatalf("upsert: fr=%d jt=%d", fr, jt)
		}
		// Row count must remain 1 (UPSERT not duplicate INSERT).
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship WHERE char_id=9000420`).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("dup row: count=%d", n)
		}
	})

	t.Run("aion_GetFactionFriendshipList returns all factions for a char", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000421, "Diplo2")
		for _, fid := range []int16{1, 2, 3} {
			if err := pool.CallSPExec(ctx, "aion_putfactionfriendship",
				9000421, fid, 50*int(fid), int(fid)*10); err != nil {
				t.Fatalf("seed %d: %v", fid, err)
			}
		}
		rows, err := pool.CallSP(ctx, "aion_getfactionfriendshiplist", 9000421)
		if err != nil {
			t.Fatalf("call: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 3 {
			t.Fatalf("rows: got %d, want 3", n)
		}
	})

	t.Run("aion_DeleteFactionFriendship soft-deletes via jointime=0", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000422, "Diplo3")
		if err := pool.CallSPExec(ctx, "aion_putfactionfriendship",
			9000422, int16(7), 250, 1500000000); err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_deletefactionfriendship",
			9000422, int16(7)); err != nil {
			t.Fatalf("del: %v", err)
		}
		var jt int
		var fr int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT jointime, friendship FROM user_faction_friendship
			  WHERE char_id=9000422 AND faction_id=7`).Scan(&jt, &fr); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if jt != 0 {
			t.Fatalf("jointime not zeroed: %d", jt)
		}
		if fr != 250 {
			t.Fatalf("friendship was modified: %d (should remain 250)", fr)
		}
	})

	// =================================================================
	// Block list (4)
	// =================================================================

	t.Run("aion_AddBlock idempotent + RemoveBlock", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000430, "Blocker")
		seedRound8Char(t, ctx, pool, 9000431, "Target1")
		if err := pool.CallSPExec(ctx, "aion_addblock",
			9000430, 9000431, "spammer"); err != nil {
			t.Fatalf("add1: %v", err)
		}
		// Second add same pair → no-op (idempotent).
		if err := pool.CallSPExec(ctx, "aion_addblock",
			9000430, 9000431, "ignored comment"); err != nil {
			t.Fatalf("add2: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id=9000430 AND block_id=9000431`).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("dup: count=%d", n)
		}
		// Original comment preserved (DO NOTHING semantics).
		var c string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM user_block WHERE char_id=9000430 AND block_id=9000431`).Scan(&c); err != nil {
			t.Fatalf("c: %v", err)
		}
		if c != "spammer" {
			t.Fatalf("comment: %q", c)
		}
		if err := pool.CallSPExec(ctx, "aion_removeblock", 9000430, 9000431); err != nil {
			t.Fatalf("remove: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_block WHERE char_id=9000430 AND block_id=9000431`).Scan(&n); err != nil {
			t.Fatalf("count2: %v", err)
		}
		if n != 0 {
			t.Fatalf("not removed: %d", n)
		}
	})

	t.Run("aion_GetBlock joins user_data; aion_GetBlockIdList returns ids", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000432, "Blocker2")
		seedRound8Char(t, ctx, pool, 9000433, "Target2")
		seedRound8Char(t, ctx, pool, 9000434, "Target3")
		if err := pool.CallSPExec(ctx, "aion_addblock", 9000432, 9000433, "noisy"); err != nil {
			t.Fatalf("a1: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_addblock", 9000432, 9000434, "spam"); err != nil {
			t.Fatalf("a2: %v", err)
		}
		// GetBlock — full rows.
		rows, err := pool.CallSP(ctx, "aion_getblock", 9000432)
		if err != nil {
			t.Fatalf("getblock: %v", err)
		}
		var n int
		for rows.Next() {
			var (
				bid     int
				uid, c  string
			)
			if err := rows.Scan(&bid, &uid, &c); err != nil {
				rows.Close()
				t.Fatalf("scan: %v", err)
			}
			if uid == "" {
				t.Fatalf("missing user_id from join")
			}
			n++
		}
		rows.Close()
		if n != 2 {
			t.Fatalf("getblock rows: %d, want 2", n)
		}
		// GetBlockIdList — just ids.
		rows2, err := pool.CallSP(ctx, "aion_getblockidlist", 9000432)
		if err != nil {
			t.Fatalf("getidlist: %v", err)
		}
		var ids int
		for rows2.Next() {
			var bid int
			if err := rows2.Scan(&bid); err != nil {
				rows2.Close()
				t.Fatalf("scan2: %v", err)
			}
			ids++
		}
		rows2.Close()
		if ids != 2 {
			t.Fatalf("getidlist: %d, want 2", ids)
		}
	})

	// =================================================================
	// Sticker / app installation (2)
	// =================================================================

	t.Run("aion_PutCanMakeSticker_20131202 + aion_GetCanMakeSticker upsert+read", func(t *testing.T) {
		seedRound8Char(t, ctx, pool, 9000440, "StickerOwn")
		// First call: insert (can_make=1, login=1700000000).
		if err := pool.CallSPExec(ctx, "aion_putcanmakesticker_20131202",
			9000440, int16(1), 1700000000); err != nil {
			t.Fatalf("first: %v", err)
		}
		// Second call: NCSoft preserves can_make=1 (UPDATE branch only refreshes login_time).
		if err := pool.CallSPExec(ctx, "aion_putcanmakesticker_20131202",
			9000440, int16(0), 1800000000); err != nil {
			t.Fatalf("second: %v", err)
		}
		var canMake int16
		var loginTime int
		if err := pool.CallSPRow(ctx, "aion_getcanmakesticker", 9000440).
			Scan(&canMake, &loginTime); err != nil {
			t.Fatalf("get: %v", err)
		}
		if canMake != 1 {
			t.Fatalf("canMake should remain 1 (NCSoft does NOT refresh on UPDATE), got %d", canMake)
		}
		if loginTime != 1800000000 {
			t.Fatalf("login_time not refreshed: %d", loginTime)
		}
	})

	// =================================================================
	// Guild nickname (1)
	// =================================================================

	t.Run("aion_SetGuildMemberNickName guards on guild_id", func(t *testing.T) {
		// Seed: char with guild_id=8000.
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, guild_id, user_id) VALUES (9000450, 'GMember', 8000, 'b6test_gm')`)
		if err != nil {
			t.Fatalf("seed: %v", err)
		}
		// Correct guild_id → updates.
		if err := pool.CallSPExec(ctx, "aion_setguildmembernickname",
			8000, 9000450, "VIP"); err != nil {
			t.Fatalf("set ok: %v", err)
		}
		var nick string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT guild_nickname FROM user_data WHERE char_id=9000450`).Scan(&nick); err != nil {
			t.Fatalf("verify1: %v", err)
		}
		if nick != "VIP" {
			t.Fatalf("nick: got %q, want 'VIP'", nick)
		}
		// Wrong guild_id → silent no-op.
		if err := pool.CallSPExec(ctx, "aion_setguildmembernickname",
			9999, 9000450, "Hacked"); err != nil {
			t.Fatalf("set wrong-guild: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT guild_nickname FROM user_data WHERE char_id=9000450`).Scan(&nick); err != nil {
			t.Fatalf("verify2: %v", err)
		}
		if nick != "VIP" {
			t.Fatalf("nick changed by wrong guild: %q", nick)
		}
	})
}

// TestPortedSPs_Smoke_E2E_Round8 — housing+pet+social wired together.
//
// Chain (8 steps):
//   H1 PutHouseInstant     — owner gets a fresh cell
//   H2 PutHouseObject ×2   — drop two pieces of furniture
//   H3 GetHouseObjectInstant — list, expect 2
//   H4 SetHouseObject      — move one piece
//   H5 GetHouseInstant     — joins user_data; verify owner user_id
//   P1 PutPetNew2          — adopt a pet
//   P2 GetPetListNew2      — see it in the list
//   S1 PutCanMakeSticker_20131202 + GetCanMakeSticker — sticker entitlement
func TestPortedSPs_Smoke_E2E_Round8(t *testing.T) {
	pool, ctx, _ := setupRound8(t)

	owner := 9000460
	seedRound8Char(t, ctx, pool, owner, "E2EOwner")

	// H1: instantiate house cell.
	if err := pool.CallSPExec(ctx, "aion_puthouseinstant",
		owner, int16(2), int16(1), 0, 0); err != nil {
		t.Fatalf("H1: %v", err)
	}

	// H2: drop two pieces of furniture.
	var idA, idB int64
	if err := pool.CallSPRow(ctx, "aion_puthouseobject",
		88001, int16(1), owner, int16(1), int16(1), 0).Scan(&idA); err != nil {
		t.Fatalf("H2a: %v", err)
	}
	if err := pool.CallSPRow(ctx, "aion_puthouseobject",
		88002, int16(1), owner, int16(1), int16(1), 0).Scan(&idB); err != nil {
		t.Fatalf("H2b: %v", err)
	}

	// H3: list — expect 2 active.
	rows, err := pool.CallSP(ctx, "aion_gethouseobjectinstant", owner)
	if err != nil {
		t.Fatalf("H3: %v", err)
	}
	var n int
	for rows.Next() {
		n++
	}
	rows.Close()
	if n != 2 {
		t.Fatalf("H3: got %d, want 2", n)
	}

	// H4: move idA to (10,20,30).
	if err := pool.CallSPExec(ctx, "aion_sethouseobject",
		idA, 88001, int16(1), owner, int16(1), int16(1), 0, 0,
		301, float32(10), float32(20), float32(30), int16(0), 0, 0); err != nil {
		t.Fatalf("H4: %v", err)
	}
	var x, y, z float32
	if err := pool.Inner().QueryRow(ctx,
		`SELECT xlocation, ylocation, zlocation FROM houseobject WHERE id=$1`, idA).
		Scan(&x, &y, &z); err != nil {
		t.Fatalf("H4 verify: %v", err)
	}
	if x != 10 || y != 20 || z != 30 {
		t.Fatalf("H4 coords: %f,%f,%f", x, y, z)
	}

	// H5: GetHouseInstant should return our owner's user_id.
	var (
		st, perm     int16
		inwall, infl int
		uid          string
	)
	if err := pool.CallSPRow(ctx, "aion_gethouseinstant", owner).
		Scan(&st, &perm, &inwall, &infl, &uid); err != nil {
		t.Fatalf("H5: %v", err)
	}
	if uid != "b6test_E2EOwner" {
		t.Fatalf("H5 uid: %q", uid)
	}

	// P1: adopt a pet.
	var pid int64
	if err := pool.CallSPRow(ctx, "aion_putpetnew2",
		"Loyalty", []byte{0xCA, 0xFE},
		owner, 600100, int16(1),
		int64(7), int64(0), int64(0), int64(0),
		int64(8), int64(0), int64(0), int64(0),
		2, 1900000000).Scan(&pid); err != nil {
		t.Fatalf("P1: %v", err)
	}
	if pid <= 0 {
		t.Fatalf("P1 pid: %d", pid)
	}

	// P2: list — should have 1 pet.
	rows2, err := pool.CallSP(ctx, "aion_getpetlistnew2", owner)
	if err != nil {
		t.Fatalf("P2: %v", err)
	}
	var pn int
	for rows2.Next() {
		pn++
	}
	rows2.Close()
	if pn != 1 {
		t.Fatalf("P2 list: %d", pn)
	}

	// S1: sticker entitlement.
	if err := pool.CallSPExec(ctx, "aion_putcanmakesticker_20131202",
		owner, int16(1), 2000000000); err != nil {
		t.Fatalf("S1 put: %v", err)
	}
	var canMake int16
	var lt int
	if err := pool.CallSPRow(ctx, "aion_getcanmakesticker", owner).Scan(&canMake, &lt); err != nil {
		t.Fatalf("S1 get: %v", err)
	}
	if canMake != 1 || lt != 2000000000 {
		t.Fatalf("S1 final: canMake=%d lt=%d", canMake, lt)
	}

	t.Logf("E2E Round 8 chain complete: owner %d → 2 furniture (1 moved), pet %d adopted, sticker entitled",
		owner, pid)
}
