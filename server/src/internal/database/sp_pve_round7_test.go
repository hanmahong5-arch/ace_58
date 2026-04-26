// Package database — Round 7 (Track B5) integration tests for the 19 newly-
// ported NCSoft stored procedures.
//
// Layout follows sp_pve_test.go / sp_pve_round6_test.go: every subtest is
// independent and reaches into the well-known cleanup bands so concurrent
// failures cannot leak fixtures.
//
// Round 7 SPs covered (19 total):
//   Legion-Dominion (6):
//     aion_LoadLegionDominionLastestTakeOverTime,
//     aion_LoadLegionDominionOwnerInfoV2,
//     aion_LoadLegionDominionRankingV2,
//     aion_ProcessLegionDominionTakeOver,
//     aion_UpdateLegionDominionRanking,
//     aion_GetHouseOwnerLegionInfo
//   Abyss (7):
//     aion_GetAbyssGuildRank, aion_SetAbyssGuildRank,
//     aion_GetAbyssRankingNew, aion_SetAbyssRank,
//     aion_GetAbyssOPPointAllAndResetTime, aion_SetAbyssOPPointAndResetTime,
//     aion_OrderingAbyssRanking_20160415
//   Auction (6):
//     aion_addAuction, aion_setauctionstate, aion_updateauctionstate,
//     aion_getauctionstate_20110609, aion_GetAuctionList_110628,
//     aion_setAuctionBetting
//
// Cleanup bands additional to fixtureCleanup() in sp_pve_test.go:
//   - char_id 9_000_300..9_000_399        (round-7 char band)
//   - guild  ‘b5test_%’ name prefix
//   - user_auction.sellername LIKE 'b5test_%'
//   - legion_dominion_rankings.server_id = 9999
//   - abyss_ranking.server_id = 9999
//   - abyss_op_point.race ∈ {99,100}
//   - user_betting.ownerid in band

package database

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// round7Cleanup wipes round-7-specific fixtures.  Called before AND after each
// test so fail-stops never leave state behind.
func round7Cleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, stmt := range []string{
		`DELETE FROM user_betting              WHERE ownerid BETWEEN 9000300 AND 9000399`,
		`DELETE FROM user_auction              WHERE sellername LIKE 'b5test_%' OR buyername LIKE 'b5test_%'`,
		`DELETE FROM user_auctionfilter        WHERE goodsid BETWEEN 999000 AND 999099`,
		`DELETE FROM legion_dominion_rankings  WHERE server_id = 9999`,
		`DELETE FROM abyss_ranking             WHERE server_id = 9999`,
		`DELETE FROM abyss_region_ranking      WHERE id BETWEEN 9000300 AND 9000399`,
		`DELETE FROM abyss_op_point            WHERE race IN (99, 100)`,
		`DELETE FROM abyss_user_owner          WHERE owner_char_id BETWEEN 9000300 AND 9000399`,
		`DELETE FROM user_gp_data              WHERE char_id BETWEEN 9000300 AND 9000399`,
		`DELETE FROM user_data                 WHERE char_id BETWEEN 9000300 AND 9000399`,
		`DELETE FROM guild                     WHERE name LIKE 'b5test_%' OR id BETWEEN 9000300 AND 9000399`,
	} {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("round7Cleanup %q: %v", stmt, err)
		}
	}
}

// setupRound7 boots PG, runs migrations, opens a pool, and registers BOTH the
// sp_pve_test.go fixtureCleanup AND round7Cleanup so combined fixtures wipe
// cleanly.
func setupRound7(t *testing.T) (*Pool, context.Context, context.CancelFunc) {
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

	round7Cleanup(t, ctx, pool)
	t.Cleanup(func() { round7Cleanup(t, context.Background(), pool) })
	return pool, ctx, cancel
}

// helper that confirms the underlying pgxpool actually exists (defensive guard
// against accidentally invoking SPs against a nil pool in test setup).
func mustPool(t *testing.T, p *Pool) *pgxpool.Pool {
	t.Helper()
	if p == nil || p.Inner() == nil {
		t.Fatal("pool is nil")
	}
	return p.Inner()
}

// TestPortedSPs_Round7 — independent per-SP tests.
func TestPortedSPs_Round7(t *testing.T) {
	pool, ctx, _ := setupRound7(t)
	_ = mustPool(t, pool)

	// =================================================================
	// Legion-Dominion (6)
	// =================================================================

	t.Run("aion_LoadLegionDominionLastestTakeOverTime returns max processed time", func(t *testing.T) {
		// Empty server → 0
		var got int64
		if err := pool.CallSPRow(ctx, "aion_loadlegiondominionlastesttakeovertime", 9999).Scan(&got); err != nil {
			t.Fatalf("empty: %v", err)
		}
		if got != 0 {
			t.Fatalf("empty: got %d, want 0", got)
		}
		// Seed three rows; the max processed_time should be 222.
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO legion_dominion_rankings
			       (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
			        take_over_processed_time, server_id)
			VALUES (1, 1, 100, 60, 1000, 111, 9999),
			       (2, 1, 200, 60, 1000, 222, 9999),
			       (3, 1,  50, 60, 1000,   0, 9999)`)
		if err != nil {
			t.Fatalf("seed: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_loadlegiondominionlastesttakeovertime", 9999).Scan(&got); err != nil {
			t.Fatalf("seeded: %v", err)
		}
		if got != 222 {
			t.Fatalf("seeded: got %d, want 222", got)
		}
	})

	t.Run("aion_LoadLegionDominionOwnerInfoV2 returns rank-1 winner per dominion", func(t *testing.T) {
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO guild(id, name, race, master_id, emblem_img_version, emblem_bgcolor)
			VALUES (9000301, 'b5test_winner', 1, 100, 7, 0xFF0000),
			       (9000302, 'b5test_loser',  1, 200, 3, 0x00FF00)`)
		if err != nil {
			t.Fatalf("seed guilds: %v", err)
		}
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO legion_dominion_rankings
			       (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
			        take_over_processed_time, server_id)
			VALUES (9000301, 1, 500, 60, 1000, 333, 9999),
			       (9000302, 1, 100, 60, 1000, 333, 9999),
			       (9000301, 2, 999, 60, 1000, 333, 9999)`)
		if err != nil {
			t.Fatalf("seed ldr: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_loadlegiondominionownerinfov2", int64(333), 9999)
		if err != nil {
			t.Fatalf("call: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			var (
				dom, lid, master, bgcol int
				race, emblemVer         int16
				name                    string
			)
			if err := rows.Scan(&dom, &lid, &race, &master, &emblemVer, &bgcol, &name); err != nil {
				t.Fatalf("scan: %v", err)
			}
			if lid != 9000301 {
				t.Fatalf("rank-1 winner mismatch dom=%d: got legion %d", dom, lid)
			}
			if name != "b5test_winner" {
				t.Fatalf("name mismatch: %q", name)
			}
			n++
		}
		if n != 2 {
			t.Fatalf("dominion count: got %d, want 2", n)
		}
	})

	t.Run("aion_LoadLegionDominionRankingV2 lists in-flight scores", func(t *testing.T) {
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO guild(id, name, race) VALUES (9000311, 'b5test_lr', 1)`)
		if err != nil {
			t.Fatalf("seed guild: %v", err)
		}
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO legion_dominion_rankings
			       (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
			        take_over_processed_time, server_id)
			VALUES (9000311, 7, 250, 60, 1000, 0, 9999),
			       (9000311, 7, 999, 60, 1000, 444, 9999) -- already processed → excluded
			`)
		if err != nil {
			t.Fatalf("seed ldr: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_loadlegiondominionrankingv2", 7, 9999)
		if err != nil {
			t.Fatalf("call: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 1 {
			t.Fatalf("got %d rows, want 1 (only in-flight)", n)
		}
	})

	t.Run("aion_ProcessLegionDominionTakeOver stamps cycle and evicts old rows", func(t *testing.T) {
		// Seed two in-flight rows
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO legion_dominion_rankings
			       (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
			        take_over_processed_time, server_id)
			VALUES (9000321, 5, 100, 60, 1000, 0, 9999),
			       (9000322, 5, 200, 60, 1000, 0, 9999)`)
		if err != nil {
			t.Fatalf("seed: %v", err)
		}
		// Old row (>30 days back) should be evicted.
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO legion_dominion_rankings
			       (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
			        take_over_processed_time, server_id)
			VALUES (9000323, 5, 0, 0, 0, 1, 9999)`)
		if err != nil {
			t.Fatalf("seed old: %v", err)
		}
		// Take-over time must be > current max (which is 1).  Use 30d+1000 so 1 lands < (newTime-30d).
		newTOT := int64(2592000 + 1000)
		if err := pool.CallSPExec(ctx, "aion_processlegiondominiontakeover", newTOT, 9999); err != nil {
			t.Fatalf("call: %v", err)
		}
		// In-flight rows should now have take_over_processed_time = newTOT
		var stamped int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM legion_dominion_rankings
			  WHERE server_id=9999 AND take_over_processed_time = $1
			    AND legion_id IN (9000321,9000322)`, newTOT).Scan(&stamped); err != nil {
			t.Fatalf("verify stamp: %v", err)
		}
		if stamped != 2 {
			t.Fatalf("stamped: got %d, want 2", stamped)
		}
		// Sentinel row inserted (legion_id=0)
		var sentinel int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM legion_dominion_rankings
			  WHERE server_id=9999 AND legion_id=0 AND take_over_processed_time=$1`, newTOT).Scan(&sentinel); err != nil {
			t.Fatalf("verify sentinel: %v", err)
		}
		if sentinel != 1 {
			t.Fatalf("sentinel: got %d, want 1", sentinel)
		}
		// 30-day-old row evicted
		var old int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM legion_dominion_rankings
			  WHERE server_id=9999 AND legion_id=9000323`).Scan(&old); err != nil {
			t.Fatalf("verify evict: %v", err)
		}
		if old != 0 {
			t.Fatalf("old row not evicted: %d", old)
		}
	})

	t.Run("aion_UpdateLegionDominionRanking inserts then updates in-place", func(t *testing.T) {
		// First call: should INSERT
		if err := pool.CallSPExec(ctx, "aion_updatelegiondominionranking",
			9000331, "b5test_lname", 9, 100, 60, int64(1000), 9999); err != nil {
			t.Fatalf("insert: %v", err)
		}
		var sc, pt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT score, played_time_in_sec FROM legion_dominion_rankings
			  WHERE legion_id=9000331 AND dominion_id=9 AND take_over_processed_time=0 AND server_id=9999`).
			Scan(&sc, &pt); err != nil {
			t.Fatalf("verify insert: %v", err)
		}
		if sc != 100 || pt != 60 {
			t.Fatalf("insert mismatch: sc=%d pt=%d", sc, pt)
		}
		// Second call: should UPDATE
		if err := pool.CallSPExec(ctx, "aion_updatelegiondominionranking",
			9000331, "b5test_lname", 9, 555, 99, int64(2000), 9999); err != nil {
			t.Fatalf("update: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT score, played_time_in_sec FROM legion_dominion_rankings
			  WHERE legion_id=9000331 AND dominion_id=9 AND take_over_processed_time=0 AND server_id=9999`).
			Scan(&sc, &pt); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if sc != 555 || pt != 99 {
			t.Fatalf("update mismatch: sc=%d pt=%d", sc, pt)
		}
		// Total rows for this combo must remain 1 (UPDATE not duplicate INSERT).
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM legion_dominion_rankings WHERE legion_id=9000331 AND dominion_id=9 AND server_id=9999`).
			Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("dup inserted: count=%d", n)
		}
	})

	t.Run("aion_GetHouseOwnerLegionInfo returns char's guild_id", func(t *testing.T) {
		_, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, guild_id) VALUES (9000341, 'HouseOwn', 5050)`)
		if err != nil {
			t.Fatalf("seed: %v", err)
		}
		var gid int
		if err := pool.CallSPRow(ctx, "aion_gethouseownerlegioninfo", 9000341).Scan(&gid); err != nil {
			t.Fatalf("call: %v", err)
		}
		if gid != 5050 {
			t.Fatalf("gid: got %d, want 5050", gid)
		}
		// Unknown char → 0
		if err := pool.CallSPRow(ctx, "aion_gethouseownerlegioninfo", 9000349).Scan(&gid); err != nil {
			t.Fatalf("missing: %v", err)
		}
		if gid != 0 {
			t.Fatalf("missing: got %d, want 0", gid)
		}
	})

	// =================================================================
	// Abyss (7)
	// =================================================================

	t.Run("aion_SetAbyssGuildRank + GetAbyssGuildRank refreshes top-50 cache", func(t *testing.T) {
		// Seed 3 race=99 guilds with different points; rank should sort desc.
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO guild(id, name, race, level, point, point_max_time)
			VALUES (9000351, 'b5test_g_high', 99, 5, 1000, 1),
			       (9000352, 'b5test_g_mid',  99, 3,  500, 2),
			       (9000353, 'b5test_g_low',  99, 1,  100, 3)`)
		if err != nil {
			t.Fatalf("seed guilds: %v", err)
		}
		// give the guilds member counts via user_data join
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO user_data(char_id, name, guild_id)
			VALUES (9000354, 'm1', 9000351),
			       (9000355, 'm2', 9000351),
			       (9000356, 'm3', 9000352)`)
		if err != nil {
			t.Fatalf("seed members: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setabyssguildrank", 99); err != nil {
			t.Fatalf("SetAbyssGuildRank: %v", err)
		}
		// Verify guild.rank assigned
		var r1, r2, r3 int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM guild WHERE id=9000351`).Scan(&r1); err != nil {
			t.Fatalf("rank1: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM guild WHERE id=9000352`).Scan(&r2); err != nil {
			t.Fatalf("rank2: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM guild WHERE id=9000353`).Scan(&r3); err != nil {
			t.Fatalf("rank3: %v", err)
		}
		if !(r1 == 1 && r2 == 2 && r3 == 3) {
			t.Fatalf("rank order wrong: %d %d %d", r1, r2, r3)
		}
		// GetAbyssGuildRank should return 3 race-99 entries.
		rows, err := pool.CallSP(ctx, "aion_getabyssguildrank")
		if err != nil {
			t.Fatalf("GetAbyssGuildRank: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n < 3 {
			t.Fatalf("got %d rows, want >=3", n)
		}
	})

	t.Run("aion_GetAbyssRankingNew returns top-N joined rows", func(t *testing.T) {
		// Seed: 2 chars with abyss_ranking rows.
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO user_data(char_id, name, user_id, gender)
			VALUES (9000361, 'AbHero1', 'b4test_ab1', false),
			       (9000362, 'AbHero2', 'b4test_ab2', true)`)
		if err != nil {
			t.Fatalf("seed users: %v", err)
		}
		now := int64(time.Now().Unix())
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO abyss_ranking
			       (abyss_ranking, server_id, update_time, char_id, abyss_point,
			        race, class, lev, guild_id)
			VALUES (1, 9999, $1, 9000361, 5000, 1, 3, 65, 0),
			       (2, 9999, $1, 9000362, 4000, 1, 5, 60, 0)`, now)
		if err != nil {
			t.Fatalf("seed ar: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getabyssrankingnew", 9999, 1, 10)
		if err != nil {
			t.Fatalf("call: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 2 {
			t.Fatalf("got %d rows, want 2", n)
		}
	})

	t.Run("aion_SetAbyssRank updates rank in [min,max] window", func(t *testing.T) {
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO user_data(char_id, name) VALUES (9000371, 'SAR1'), (9000372, 'SAR2'), (9000373, 'SAR3')`)
		if err != nil {
			t.Fatalf("seed users: %v", err)
		}
		now := int64(time.Now().Unix()) + 7777
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO abyss_ranking
			       (abyss_ranking, server_id, update_time, char_id, abyss_point, race, class, lev, guild_id)
			VALUES (10, 9999, $1, 9000371, 1, 2, 1, 1, 0),
			       (11, 9999, $1, 9000372, 1, 2, 1, 1, 0),
			       (12, 9999, $1, 9000373, 1, 2, 1, 1, 0)`, now)
		if err != nil {
			t.Fatalf("seed ar: %v", err)
		}
		// stamp rank=99 to abyss_ranking 11..12 only.
		if err := pool.CallSPExec(ctx, "aion_setabyssrank", 9999, 2, now, 99, 11, 12); err != nil {
			t.Fatalf("call: %v", err)
		}
		var r10, r11 int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM abyss_ranking WHERE abyss_ranking=10 AND update_time=$1 AND server_id=9999`, now).Scan(&r10); err != nil {
			t.Fatalf("r10: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM abyss_ranking WHERE abyss_ranking=11 AND update_time=$1 AND server_id=9999`, now).Scan(&r11); err != nil {
			t.Fatalf("r11: %v", err)
		}
		if r10 != 0 || r11 != 99 {
			t.Fatalf("ranks: 10=%d 11=%d (want 0/99)", r10, r11)
		}
	})

	t.Run("aion_SetAbyssOPPointAndResetTime upserts and GetAbyssOPPointAllAndResetTime reads", func(t *testing.T) {
		// First insert
		if err := pool.CallSPExec(ctx, "aion_setabyssoppointandresettime",
			99, 100, 200, 300, 400, 500, 600, 700, 1700000000); err != nil {
			t.Fatalf("insert: %v", err)
		}
		// Update
		if err := pool.CallSPExec(ctx, "aion_setabyssoppointandresettime",
			99, 999, 200, 300, 400, 500, 600, 700, 1800000000); err != nil {
			t.Fatalf("update: %v", err)
		}
		var quest, nextReset int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT quest, next_reset_time FROM abyss_op_point WHERE race=99`).Scan(&quest, &nextReset); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if quest != 999 || nextReset != 1800000000 {
			t.Fatalf("upsert: quest=%d next=%d (want 999/1800000000)", quest, nextReset)
		}
		// And read back via the Get SP
		rows, err := pool.CallSP(ctx, "aion_getabyssoppointallandresettime")
		if err != nil {
			t.Fatalf("Get: %v", err)
		}
		defer rows.Close()
		var seen bool
		for rows.Next() {
			seen = true
		}
		if !seen {
			t.Fatalf("Get returned no rows")
		}
	})

	t.Run("aion_OrderingAbyssRanking_20160415 special-svr branch produces a snapshot", func(t *testing.T) {
		// Seed 2 chars with abyss_point + recent logout.
		_, err := pool.Inner().Exec(ctx, `
			INSERT INTO user_data(char_id, name, race, class, lev, abyss_point, org_server,
			                      delete_date, last_logout_time)
			VALUES (9000381, 'OAR1', 99, 1, 60, 5000, 9999, 0, NOW() - INTERVAL '1 day'),
			       (9000382, 'OAR2', 99, 2, 55, 3000, 9999, 0, NOW() - INTERVAL '5 day')`)
		if err != nil {
			t.Fatalf("seed users: %v", err)
		}
		_, err = pool.Inner().Exec(ctx, `
			INSERT INTO user_gp_data(char_id, glory_point, ownership_bonus_gp)
			VALUES (9000381, 100, 50), (9000382, 200, 0)`)
		if err != nil {
			t.Fatalf("seed gp: %v", err)
		}
		newTime := int64(time.Now().Unix()) + 8888
		// _is_special_svr=1 → bypass GP-window filter
		if err := pool.CallSPExec(ctx, "aion_orderingabyssranking_20160415",
			1, 9999, 99, newTime, 100, int(time.Now().Unix()), 0); err != nil {
			t.Fatalf("call: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM abyss_ranking WHERE update_time=$1 AND server_id=9999`, newTime).Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 2 {
			t.Fatalf("snapshot rows: %d, want 2", n)
		}
	})

	// =================================================================
	// Auction (6)
	// =================================================================

	t.Run("aion_addAuction lists and rejects duplicates", func(t *testing.T) {
		var newID int64
		err := pool.CallSPRow(ctx, "aion_addauction",
			0, 1, 999001, 9000391, "b5test_seller1",
			int64(10000), int64(500), int(time.Now().Unix())).Scan(&newID)
		if err != nil {
			t.Fatalf("first: %v", err)
		}
		if newID <= 0 {
			t.Fatalf("first: got id %d, want >0", newID)
		}
		// Second call same goods → 0 (blocked: in-flight)
		var dupID int64
		if err := pool.CallSPRow(ctx, "aion_addauction",
			0, 1, 999001, 9000392, "b5test_seller2",
			int64(20000), int64(500), int(time.Now().Unix())).Scan(&dupID); err != nil {
			t.Fatalf("dup: %v", err)
		}
		if dupID != 0 {
			t.Fatalf("dup: got id %d, want 0", dupID)
		}
		// Insert into filter list and try fresh goods → 0 (blocked: filter)
		_, err = pool.Inner().Exec(ctx,
			`INSERT INTO user_auctionfilter(type, goodsid) VALUES (0, 999002)`)
		if err != nil {
			t.Fatalf("seed filter: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_addauction",
			0, 1, 999002, 9000393, "b5test_seller3",
			int64(1), int64(1), int(time.Now().Unix())).Scan(&dupID); err != nil {
			t.Fatalf("filter: %v", err)
		}
		if dupID != 0 {
			t.Fatalf("filter: got id %d, want 0", dupID)
		}
	})

	t.Run("aion_setauctionstate flips the state", func(t *testing.T) {
		var aid int64
		if err := pool.CallSPRow(ctx, "aion_addauction",
			1, 1, 999003, 9000394, "b5test_setstate",
			int64(50000), int64(1000), int(time.Now().Unix())).Scan(&aid); err != nil {
			t.Fatalf("add: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setauctionstate", aid, 2); err != nil {
			t.Fatalf("set: %v", err)
		}
		var st int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT state FROM user_auction WHERE id=$1`, aid).Scan(&st); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if st != 2 {
			t.Fatalf("state: got %d, want 2", st)
		}
	})

	t.Run("aion_updateauctionstate updates bid + buyer + betcount", func(t *testing.T) {
		var aid int64
		if err := pool.CallSPRow(ctx, "aion_addauction",
			2, 1, 999004, 9000395, "b5test_updstate",
			int64(100000), int64(5000), int(time.Now().Unix())).Scan(&aid); err != nil {
			t.Fatalf("add: %v", err)
		}
		now := int(time.Now().Unix())
		if err := pool.CallSPExec(ctx, "aion_updateauctionstate",
			aid, int64(150000), now, 9000396, "b5test_buyer1"); err != nil {
			t.Fatalf("upd1: %v", err)
		}
		// Second bid bumps betcount to 2.
		if err := pool.CallSPExec(ctx, "aion_updateauctionstate",
			aid, int64(200000), now+1, 9000397, "b5test_buyer2"); err != nil {
			t.Fatalf("upd2: %v", err)
		}
		var (
			qina    int64
			buyer   int
			bname   string
			bcount  int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT qina, buyerid, buyername, betcount FROM user_auction WHERE id=$1`, aid).
			Scan(&qina, &buyer, &bname, &bcount); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if qina != 200000 || buyer != 9000397 || bname != "b5test_buyer2" || bcount != 2 {
			t.Fatalf("update: qina=%d buyer=%d name=%q bcount=%d", qina, buyer, bname, bcount)
		}
	})

	t.Run("aion_getauctionstate_20110609 reads single row", func(t *testing.T) {
		var aid int64
		if err := pool.CallSPRow(ctx, "aion_addauction",
			3, 1, 999005, 9000398, "b5test_getstate",
			int64(75000), int64(2500), int(time.Now().Unix())).Scan(&aid); err != nil {
			t.Fatalf("add: %v", err)
		}
		var (
			buyer   int
			bname   string
			initq   int64
			qina    int64
			st      int16
		)
		if err := pool.CallSPRow(ctx, "aion_getauctionstate_20110609", aid).
			Scan(&buyer, &bname, &initq, &qina, &st); err != nil {
			t.Fatalf("get: %v", err)
		}
		if initq != 75000 || qina != 75000 || st != 0 {
			t.Fatalf("get: initq=%d qina=%d st=%d", initq, qina, st)
		}
	})

	t.Run("aion_GetAuctionList_110628 returns matching in-flight auctions", func(t *testing.T) {
		// Add 2 auctions of (type=4, race=1) plus a settled one.
		var a1, a2, a3 int64
		if err := pool.CallSPRow(ctx, "aion_addauction",
			4, 1, 999010, 9000399, "b5test_l1", int64(1), int64(1), int(time.Now().Unix())).Scan(&a1); err != nil {
			t.Fatalf("a1: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_addauction",
			4, 1, 999011, 9000399, "b5test_l2", int64(1), int64(1), int(time.Now().Unix())).Scan(&a2); err != nil {
			t.Fatalf("a2: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_addauction",
			4, 1, 999012, 9000399, "b5test_l3", int64(1), int64(1), int(time.Now().Unix())).Scan(&a3); err != nil {
			t.Fatalf("a3: %v", err)
		}
		// flip a3 to state=5 → excluded
		if err := pool.CallSPExec(ctx, "aion_setauctionstate", a3, 5); err != nil {
			t.Fatalf("set a3: %v", err)
		}
		rows, err := pool.CallSP(ctx, "aion_getauctionlist_110628", 1, 4)
		if err != nil {
			t.Fatalf("list: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 2 {
			t.Fatalf("list count: got %d, want 2 (a3 should be filtered)", n)
		}
	})

	t.Run("aion_setAuctionBetting upserts per-character active bet", func(t *testing.T) {
		// First call: insert.
		var ret int
		if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
			9000300, int64(123), int64(50000)).Scan(&ret); err != nil {
			t.Fatalf("first: %v", err)
		}
		if ret != 9000300 {
			t.Fatalf("ret: got %d, want 9000300", ret)
		}
		// Second call: update (same ownerid, new auction).
		if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
			9000300, int64(456), int64(99999)).Scan(&ret); err != nil {
			t.Fatalf("second: %v", err)
		}
		var aid int64
		var qina int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT auctionid, qina FROM user_betting WHERE ownerid=9000300`).Scan(&aid, &qina); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if aid != 456 || qina != 99999 {
			t.Fatalf("upsert: aid=%d qina=%d", aid, qina)
		}
		// Idempotent: row count is 1.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_betting WHERE ownerid=9000300`).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("dup: count=%d", n)
		}
	})
}

// TestPortedSPs_Smoke_E2E_Round7 — siege+abyss+auction wired together.
//
// Chain (12 steps):
//   L1 PutGuild (b5test_legion_e2e) — gets guild id
//   L2 UpdateLegionDominionRanking — start a cycle
//   L3 UpdateLegionDominionRanking again — UPDATE same row
//   L4 LoadLegionDominionRankingV2 — verify cycle visible
//   L5 ProcessLegionDominionTakeOver — close cycle
//   L6 LoadLegionDominionLastestTakeOverTime — verify processed_time updated
//   A1 SetAbyssOPPointAndResetTime (race=100) — first cache write
//   A2 SetAbyssGuildRank (race=99) + GetAbyssGuildRank — refresh leaderboard
//   A3 SetAbyssRank — bulk-stamp ranks (no-op when no abyss_ranking rows; verifies SP signature)
//   X1 addAuction — list a house
//   X2 updateauctionstate — bid
//   X3 setAuctionBetting + setauctionstate(2) — close out
func TestPortedSPs_Smoke_E2E_Round7(t *testing.T) {
	pool, ctx, _ := setupRound7(t)

	// L1 — create a legion via the existing PutGuild SP from earlier rounds.
	var gid int
	if err := pool.CallSPRow(ctx, "aion_putguild_20100916",
		"b5test_legion_e2e", 9000300, 1, 0, 0, 0, 0).Scan(&gid); err != nil {
		t.Fatalf("L1 PutGuild: %v", err)
	}
	t.Logf("L1: created legion id=%d", gid)

	// L2: in-flight ranking row (insert).
	if err := pool.CallSPExec(ctx, "aion_updatelegiondominionranking",
		gid, "b5test_legion_e2e", 11, 100, 60, int64(1000), 9999); err != nil {
		t.Fatalf("L2 UpdateLDR insert: %v", err)
	}
	// L3: same legion+dominion (update path).
	if err := pool.CallSPExec(ctx, "aion_updatelegiondominionranking",
		gid, "b5test_legion_e2e", 11, 999, 120, int64(2000), 9999); err != nil {
		t.Fatalf("L3 UpdateLDR update: %v", err)
	}

	// L4: in-flight scores visible
	rows, err := pool.CallSP(ctx, "aion_loadlegiondominionrankingv2", 11, 9999)
	if err != nil {
		t.Fatalf("L4 LoadLDR: %v", err)
	}
	var ln int
	for rows.Next() {
		ln++
	}
	rows.Close()
	if ln < 1 {
		t.Fatalf("L4: no rows, want >=1")
	}

	// L5: take-over time strictly newer than 0 (current max). Use 30d+now.
	totTime := int64(time.Now().Unix()) + 2592000
	if err := pool.CallSPExec(ctx, "aion_processlegiondominiontakeover", totTime, 9999); err != nil {
		t.Fatalf("L5 ProcessTakeOver: %v", err)
	}
	// L6: the lastest now equals our totTime
	var got int64
	if err := pool.CallSPRow(ctx, "aion_loadlegiondominionlastesttakeovertime", 9999).Scan(&got); err != nil {
		t.Fatalf("L6 LoadLastest: %v", err)
	}
	if got != totTime {
		t.Fatalf("L6: got %d want %d", got, totTime)
	}

	// A1: write op_point cache for race=100.
	if err := pool.CallSPExec(ctx, "aion_setabyssoppointandresettime",
		100, 50, 60, 70, 80, 90, 100, 110, 1900000000); err != nil {
		t.Fatalf("A1 SetAbyssOPPoint: %v", err)
	}
	// Verify Get returns at least one row.
	rows2, err := pool.CallSP(ctx, "aion_getabyssoppointallandresettime")
	if err != nil {
		t.Fatalf("A1 Get: %v", err)
	}
	var an int
	for rows2.Next() {
		an++
	}
	rows2.Close()
	if an < 1 {
		t.Fatalf("A1 Get: no rows")
	}

	// A2: refresh the abyss guild rank for race=1 (our legion).
	if err := pool.CallSPExec(ctx, "aion_setabyssguildrank", 1); err != nil {
		t.Fatalf("A2 SetAbyssGuildRank: %v", err)
	}

	// A3: bulk-stamp rank — empty result is fine, just verify the call succeeds.
	if err := pool.CallSPExec(ctx, "aion_setabyssrank", 9999, 1, int64(0), 0, 1, 50); err != nil {
		t.Fatalf("A3 SetAbyssRank: %v", err)
	}

	// X1: list a house. (Note: filter goodsid=999050 is not in filter list.)
	var aid int64
	if err := pool.CallSPRow(ctx, "aion_addauction",
		0, 1, 999050, gid, "b5test_e2e_seller", int64(80000), int64(2000),
		int(time.Now().Unix())).Scan(&aid); err != nil {
		t.Fatalf("X1 addAuction: %v", err)
	}
	if aid <= 0 {
		t.Fatalf("X1: aid=%d", aid)
	}

	// X2: bid.
	if err := pool.CallSPExec(ctx, "aion_updateauctionstate",
		aid, int64(120000), int(time.Now().Unix()), 9000301, "b5test_e2e_buyer"); err != nil {
		t.Fatalf("X2 updateauctionstate: %v", err)
	}

	// X3a: lock buyer's bet.
	var ret int
	if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
		9000301, aid, int64(120000)).Scan(&ret); err != nil {
		t.Fatalf("X3a setAuctionBetting: %v", err)
	}
	if ret != 9000301 {
		t.Fatalf("X3a ret: %d", ret)
	}
	// X3b: settle (state=2).
	if err := pool.CallSPExec(ctx, "aion_setauctionstate", aid, 2); err != nil {
		t.Fatalf("X3b setauctionstate: %v", err)
	}

	// Final sanity: house is now state=2, buyer recorded.
	var (
		state    int16
		bid      int
		bname    string
		curQina  int64
	)
	if err := pool.Inner().QueryRow(ctx,
		`SELECT state, buyerid, buyername, qina FROM user_auction WHERE id=$1`, aid).
		Scan(&state, &bid, &bname, &curQina); err != nil {
		t.Fatalf("final: %v", err)
	}
	if state != 2 || bid != 9000301 || bname != "b5test_e2e_buyer" || curQina != 120000 {
		t.Fatalf("final: state=%d bid=%d bname=%q qina=%d", state, bid, bname, curQina)
	}

	t.Logf("E2E Round 7 chain complete: legion %d → cycle closed → house %d sold for 120000", gid, aid)
}
