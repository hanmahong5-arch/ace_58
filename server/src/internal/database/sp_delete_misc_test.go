// Package database — integration test for batch 28 ("Delete-族杂项"):
//
//   00281 aion_DeleteAllOverseasEventQuest()
//   00282 aion_DeleteAuctionFilterList(type, goodsID)
//   00283 aion_DeleteBookmarkAll(char_id)
//   00284 aion_DeleteCharVendorDataDark(char_id)
//   00285 aion_DeleteCharVendorDataLight(char_id)
//
// All five SPs share the same shape: scoped DELETE → return rows-affected
// (NCSoft @@ROWCOUNT pin). The test exercises:
//   - happy-path delete with seeded rows
//   - idempotent re-delete (silent 0 on empty)
//   - cross-faction isolation (Dark SP must not touch Light tables, vv.)
//
// char_id band: 9_720_001 .. 9_720_099  (per task spec, batch-28 fixture
// range distinct from earlier delete-tests' 947x band).
//
// Skip-if-no-DSN: when AION_TEST_PG_* env tuple is missing, the whole
// suite is t.Skip()ped — keeps `go test ./...` clean for contributors
// without a local PG.
package database

import (
	"context"
	"testing"
	"time"
)

// Sentinel char_ids for batch-28 fixture range.
const (
	cidDelMiscBmA      = 9720001 // bookmark wipe target
	cidDelMiscBmB      = 9720002 // neighbour-isolation control
	cidDelMiscBmEmpty  = 9720003 // user_data exists, zero bookmarks
	cidDelMiscDarkA    = 9720010 // vendor_dark wipe target
	cidDelMiscLightA   = 9720011 // vendor_light wipe target
	cidDelMiscDarkX    = 9720012 // dark control: must NOT be touched by light SP
	cidDelMiscLightX   = 9720013 // light control: must NOT be touched by dark SP
	cidDelMiscDarkOnly = 9720014 // only sales log, no item rows
)

// Sentinel ids for whitelist / filter SPs.
const (
	delMiscOEQQ1 = 924001
	delMiscOEQQ2 = 924002

	delMiscFilterGoodsA = 92400121 // exists, deleted with right type
	delMiscFilterGoodsB = 92400122 // never seeded — non-existent path

	delMiscFilterTypeA = 7
)

// deleteMiscCleanup scrubs every fixture artefact this test owns. Runs
// twice: once before the suite (to recover from a previous panicked run)
// and once via t.Cleanup at the end.
func deleteMiscCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()

	// bookmark + user_data
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM bookmark WHERE char_id BETWEEN 9720001 AND 9720099`); err != nil {
		t.Fatalf("deleteMiscCleanup bookmark: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9720001 AND 9720099`); err != nil {
		t.Fatalf("deleteMiscCleanup user_data: %v", err)
	}

	// vendor_item_dark / vendor_log_dark
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM vendor_item_dark WHERE char_id BETWEEN 9720001 AND 9720099`); err != nil {
		t.Fatalf("deleteMiscCleanup vendor_item_dark: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM vendor_log_dark WHERE char_id BETWEEN 9720001 AND 9720099`); err != nil {
		t.Fatalf("deleteMiscCleanup vendor_log_dark: %v", err)
	}

	// vendor_item_light / vendor_log_light
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM vendor_item_light WHERE char_id BETWEEN 9720001 AND 9720099`); err != nil {
		t.Fatalf("deleteMiscCleanup vendor_item_light: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM vendor_log_light WHERE char_id BETWEEN 9720001 AND 9720099`); err != nil {
		t.Fatalf("deleteMiscCleanup vendor_log_light: %v", err)
	}

	// overseas_event_quest sentinel range
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM overseas_event_quest WHERE quest_id BETWEEN 924000 AND 924099`); err != nil {
		t.Fatalf("deleteMiscCleanup overseas_event_quest: %v", err)
	}

	// user_auctionfilter sentinel range
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_auctionfilter WHERE goodsID BETWEEN 92400100 AND 92400199`); err != nil {
		t.Fatalf("deleteMiscCleanup user_auctionfilter: %v", err)
	}
}

// TestSPDeleteMisc — batch-28 cohort entry-point. Each sub-test is one SP.
func TestSPDeleteMisc(t *testing.T) {
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

	deleteMiscCleanup(t, ctx, pool)
	t.Cleanup(func() { deleteMiscCleanup(t, context.Background(), pool) })

	// --------- 00281 aion_deletealloverseaseventquest ---------
	t.Run("00281_DeleteAllOverseasEventQuest", func(t *testing.T) {
		// Seed two whitelist rows in our sentinel range.
		for _, q := range []int{delMiscOEQQ1, delMiscOEQQ2} {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO overseas_event_quest(quest_id) VALUES ($1)`, q); err != nil {
				t.Fatalf("seed q=%d: %v", q, err)
			}
		}

		// Capture whole-table count (the SP wipes EVERY row, not just our 2).
		var beforeCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM overseas_event_quest`).Scan(&beforeCnt); err != nil {
			t.Fatalf("count before: %v", err)
		}
		if beforeCnt < 2 {
			t.Fatalf("pre-sweep count: got %d, want >= 2 (our 2 seeds)", beforeCnt)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletealloverseaseventquest").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow sweep: %v", err)
		}
		if affected != beforeCnt {
			t.Fatalf("sweep: got %d, want %d (whole-table count)", affected, beforeCnt)
		}

		// Idempotent: a second sweep on the now-empty table must return 0.
		var affected2 int
		if err := pool.CallSPRow(ctx, "aion_deletealloverseaseventquest").Scan(&affected2); err != nil {
			t.Fatalf("CallSPRow second sweep: %v", err)
		}
		if affected2 != 0 {
			t.Fatalf("second sweep: got %d, want 0 (idempotent)", affected2)
		}
	})

	// --------- 00282 aion_deleteauctionfilterlist ---------
	t.Run("00282_DeleteAuctionFilterList", func(t *testing.T) {
		// Seed one (type, goodsID) row.
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_auctionfilter(type, goodsID) VALUES ($1, $2)`,
			delMiscFilterTypeA, delMiscFilterGoodsA); err != nil {
			t.Fatalf("seed filter: %v", err)
		}

		// Happy path: matching (type, goodsID) → 1, row gone.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionfilterlist",
			int(delMiscFilterTypeA), int(delMiscFilterGoodsA)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow happy: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_auctionfilter WHERE goodsID=$1`,
			delMiscFilterGoodsA).Scan(&n); err != nil {
			t.Fatalf("verify happy: %v", err)
		}
		if n != 0 {
			t.Fatalf("after delete: got %d rows, want 0", n)
		}

		// Non-existent goodsID returns 0 silently.
		var affected2 int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionfilterlist",
			int(delMiscFilterTypeA), int(delMiscFilterGoodsB)).Scan(&affected2); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected2 != 0 {
			t.Fatalf("missing: got %d, want 0", affected2)
		}
	})

	// --------- 00283 aion_deletebookmarkall ---------
	t.Run("00283_DeleteBookmarkAll", func(t *testing.T) {
		// Seed user_data for three chars (one with bookmarks, one neighbour,
		// one with no bookmarks); a fourth missing char tests no-FK-guard.
		for _, seed := range []struct {
			id   int
			name string
		}{
			{cidDelMiscBmA, "DelMiscBmA"},
			{cidDelMiscBmB, "DelMiscBmB"},
			{cidDelMiscBmEmpty, "DelMiscBmEmpty"},
		} {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
				seed.id, seed.name, "del28_"+seed.name); err != nil {
				t.Fatalf("seed user_data %d: %v", seed.id, err)
			}
		}

		// Char A: 3 bookmarks. Char B: 1 bookmark (neighbour control).
		for _, slot := range []int16{0, 1, 2} {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO bookmark (char_id, bookmark, bookmark_name, world, x, y, z)
				 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
				cidDelMiscBmA, slot, "A28", int32(210010000),
				float32(0), float32(0), float32(0)); err != nil {
				t.Fatalf("seed A bookmark slot=%d: %v", slot, err)
			}
		}
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO bookmark (char_id, bookmark, bookmark_name, world, x, y, z)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscBmB, int16(0), "B28", int32(0),
			float32(0), float32(0), float32(0)); err != nil {
			t.Fatalf("seed B bookmark: %v", err)
		}

		// Happy path: A's 3 bookmarks → wipe → returns 3.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletebookmarkall",
			cidDelMiscBmA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if affected != 3 {
			t.Fatalf("A wipe: got %d, want 3", affected)
		}

		// Neighbour B intact.
		var nB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM bookmark WHERE char_id = $1`,
			cidDelMiscBmB).Scan(&nB); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if nB != 1 {
			t.Fatalf("B leaked: got %d, want 1", nB)
		}

		// Empty char returns 0.
		var affEmpty int
		if err := pool.CallSPRow(ctx, "aion_deletebookmarkall",
			cidDelMiscBmEmpty).Scan(&affEmpty); err != nil {
			t.Fatalf("CallSPRow empty: %v", err)
		}
		if affEmpty != 0 {
			t.Fatalf("empty: got %d, want 0", affEmpty)
		}

		// Idempotent re-wipe on A (now zero) returns 0.
		var affRe int
		if err := pool.CallSPRow(ctx, "aion_deletebookmarkall",
			cidDelMiscBmA).Scan(&affRe); err != nil {
			t.Fatalf("CallSPRow A re-wipe: %v", err)
		}
		if affRe != 0 {
			t.Fatalf("A re-wipe: got %d, want 0", affRe)
		}
	})

	// --------- 00284 aion_deletecharvendordatadark ---------
	t.Run("00284_DeleteCharVendorDataDark", func(t *testing.T) {
		// Seed Dark side: A has 2 items + 1 log row; X is a dark control row
		// untouched in this sub-test (verified later under cross-isolation).
		// Also seed Light side rows under the same band — verify cross-faction
		// isolation: Dark SP must NOT touch Light tables.
		mustExec := func(sql string, args ...any) {
			t.Helper()
			if _, err := pool.Inner().Exec(ctx, sql, args...); err != nil {
				t.Fatalf("seed (%s): %v", sql, err)
			}
		}

		// Dark items for A.
		mustExec(`INSERT INTO vendor_item_dark
			(char_id, user_item_id, user_price, sale_price, commit_amount,
			 remain_amount, commit_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscDarkA, int64(72000001), int64(100), int64(95),
			int64(10), int64(10), int(1700000000))
		mustExec(`INSERT INTO vendor_item_dark
			(char_id, user_item_id, user_price, sale_price, commit_amount,
			 remain_amount, commit_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscDarkA, int64(72000002), int64(200), int64(190),
			int64(20), int64(20), int(1700000001))

		// Dark log for A (1 row) and DarkOnly (1 row, log only — no items).
		mustExec(`INSERT INTO vendor_log_dark
			(char_id, item_name_id, sold_price, sold_amount, remain_amount,
			 sold_date, soul_bound, enchant_count, skin_name_id)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			cidDelMiscDarkA, int(150100), int64(95), int64(5), int64(5),
			int(1700000010), int16(0), int16(0), int(0))
		mustExec(`INSERT INTO vendor_log_dark
			(char_id, item_name_id, sold_price, sold_amount, remain_amount,
			 sold_date, soul_bound, enchant_count, skin_name_id)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			cidDelMiscDarkOnly, int(150200), int64(50), int64(1), int64(0),
			int(1700000020), int16(1), int16(0), int(0))

		// Dark control row for X — must NOT be touched by A's wipe.
		mustExec(`INSERT INTO vendor_item_dark
			(char_id, user_item_id, user_price, sale_price, commit_amount,
			 remain_amount, commit_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscDarkX, int64(72000099), int64(99), int64(99),
			int64(1), int64(1), int(1700000030))

		// Light side seed under the SAME char_id band — for cross-faction
		// isolation: the Dark SP must NOT touch these.
		mustExec(`INSERT INTO vendor_item_light
			(char_id, user_item_id, user_price, sale_price, commit_amount,
			 remain_amount, commit_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscLightA, int64(73000001), int64(100), int64(95),
			int64(10), int64(10), int(1700000000))
		mustExec(`INSERT INTO vendor_log_light
			(char_id, item_name_id, sold_price, sold_amount, remain_amount,
			 sold_date, soul_bound, enchant_count, skin_name_id)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			cidDelMiscLightA, int(160100), int64(95), int64(5), int64(5),
			int(1700000010), int16(0), int16(0), int(0))
		mustExec(`INSERT INTO vendor_item_light
			(char_id, user_item_id, user_price, sale_price, commit_amount,
			 remain_amount, commit_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscLightX, int64(73000099), int64(50), int64(50),
			int64(2), int64(2), int(1700000040))

		// Happy path: Dark SP wipes A's 2 items + 1 log = 3.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatadark",
			cidDelMiscDarkA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A dark: %v", err)
		}
		if affected != 3 {
			t.Fatalf("dark A wipe: got %d, want 3 (2 items + 1 log)", affected)
		}

		// A's dark rows gone.
		assertCount := func(label, sql string, args []any, want int) {
			t.Helper()
			var got int
			if err := pool.Inner().QueryRow(ctx, sql, args...).Scan(&got); err != nil {
				t.Fatalf("count %s: %v", label, err)
			}
			if got != want {
				t.Fatalf("count %s: got %d, want %d", label, got, want)
			}
		}
		assertCount("vendor_item_dark/A",
			`SELECT COUNT(*) FROM vendor_item_dark WHERE char_id=$1`,
			[]any{cidDelMiscDarkA}, 0)
		assertCount("vendor_log_dark/A",
			`SELECT COUNT(*) FROM vendor_log_dark WHERE char_id=$1`,
			[]any{cidDelMiscDarkA}, 0)

		// Dark control X: still there.
		assertCount("vendor_item_dark/X",
			`SELECT COUNT(*) FROM vendor_item_dark WHERE char_id=$1`,
			[]any{cidDelMiscDarkX}, 1)

		// Cross-faction isolation: light tables intact.
		assertCount("vendor_item_light/A (must survive dark wipe)",
			`SELECT COUNT(*) FROM vendor_item_light WHERE char_id=$1`,
			[]any{cidDelMiscLightA}, 1)
		assertCount("vendor_log_light/A (must survive dark wipe)",
			`SELECT COUNT(*) FROM vendor_log_light WHERE char_id=$1`,
			[]any{cidDelMiscLightA}, 1)
		assertCount("vendor_item_light/X (must survive dark wipe)",
			`SELECT COUNT(*) FROM vendor_item_light WHERE char_id=$1`,
			[]any{cidDelMiscLightX}, 1)

		// Asymmetric case: char with only log rows (no items).
		var affDarkOnly int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatadark",
			cidDelMiscDarkOnly).Scan(&affDarkOnly); err != nil {
			t.Fatalf("CallSPRow DarkOnly: %v", err)
		}
		if affDarkOnly != 1 {
			t.Fatalf("DarkOnly: got %d, want 1 (0 items + 1 log)", affDarkOnly)
		}

		// Idempotent: re-wiping A returns 0.
		var affRe int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatadark",
			cidDelMiscDarkA).Scan(&affRe); err != nil {
			t.Fatalf("CallSPRow A re-wipe: %v", err)
		}
		if affRe != 0 {
			t.Fatalf("A dark re-wipe: got %d, want 0 (idempotent)", affRe)
		}

		// Missing char (no FK guard, returns 0 silently).
		var affMissing int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatadark",
			int(9720098)).Scan(&affMissing); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affMissing != 0 {
			t.Fatalf("missing: got %d, want 0", affMissing)
		}
	})

	// --------- 00285 aion_deletecharvendordatalight ---------
	t.Run("00285_DeleteCharVendorDataLight", func(t *testing.T) {
		// 00284 already wiped Light/A's dark counterpart and exercised the
		// "Light survives Dark SP" direction. Now exercise the reverse:
		// Light SP wipes the leftover Light rows for cidDelMiscLightA, AND
		// the dark-control X must remain — which is enforced because we
		// didn't seed vendor_item_dark/X for this id (different char_id).
		// We additionally seed *fresh* dark rows under a Light id to assert
		// the Light SP does not touch *_dark even in a contrived overlap.

		mustExec := func(sql string, args ...any) {
			t.Helper()
			if _, err := pool.Inner().Exec(ctx, sql, args...); err != nil {
				t.Fatalf("seed (%s): %v", sql, err)
			}
		}

		// Seed a contrived dark row under cidDelMiscLightA — a Light char
		// would never have a dark row in production, but the bug-for-bug
		// pin is "Light SP only touches *_light", so we test it explicitly.
		mustExec(`INSERT INTO vendor_item_dark
			(char_id, user_item_id, user_price, sale_price, commit_amount,
			 remain_amount, commit_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			cidDelMiscLightA, int64(72000098), int64(1), int64(1),
			int64(1), int64(1), int(1700000050))

		// Light SP wipes A's 1 item + 1 log = 2.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatalight",
			cidDelMiscLightA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A light: %v", err)
		}
		if affected != 2 {
			t.Fatalf("light A wipe: got %d, want 2 (1 item + 1 log)", affected)
		}

		// Light tables for A: empty. Dark contrived row: still there.
		assertCount := func(label, sql string, args []any, want int) {
			t.Helper()
			var got int
			if err := pool.Inner().QueryRow(ctx, sql, args...).Scan(&got); err != nil {
				t.Fatalf("count %s: %v", label, err)
			}
			if got != want {
				t.Fatalf("count %s: got %d, want %d", label, got, want)
			}
		}
		assertCount("vendor_item_light/A",
			`SELECT COUNT(*) FROM vendor_item_light WHERE char_id=$1`,
			[]any{cidDelMiscLightA}, 0)
		assertCount("vendor_log_light/A",
			`SELECT COUNT(*) FROM vendor_log_light WHERE char_id=$1`,
			[]any{cidDelMiscLightA}, 0)
		assertCount("vendor_item_dark/A_contrived (must survive light wipe)",
			`SELECT COUNT(*) FROM vendor_item_dark WHERE char_id=$1`,
			[]any{cidDelMiscLightA}, 1)

		// Light X control intact.
		assertCount("vendor_item_light/X",
			`SELECT COUNT(*) FROM vendor_item_light WHERE char_id=$1`,
			[]any{cidDelMiscLightX}, 1)

		// Idempotent re-wipe.
		var affRe int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatalight",
			cidDelMiscLightA).Scan(&affRe); err != nil {
			t.Fatalf("CallSPRow A re-wipe: %v", err)
		}
		if affRe != 0 {
			t.Fatalf("light A re-wipe: got %d, want 0 (idempotent)", affRe)
		}

		// Missing char returns 0 silently.
		var affMissing int
		if err := pool.CallSPRow(ctx, "aion_deletecharvendordatalight",
			int(9720097)).Scan(&affMissing); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affMissing != 0 {
			t.Fatalf("missing: got %d, want 0", affMissing)
		}
	})
}
