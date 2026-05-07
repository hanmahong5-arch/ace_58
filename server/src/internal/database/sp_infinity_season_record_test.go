// Package database — integration test for the InfinitySeasonRecord SP pair
// (00264 GetInfinitySeasonRecord / 00265 SetInfinitySeasonRecord).
//
// Domain: per-character "Infinity Shard" PvP arena season reward state.
// NEW domain in batch 26. The pair upserts on `user_extra_info` keyed on
// char_id; only the (prevSeasonReward, currentSeasonReward) PascalCase
// columns are touched. The PascalCase identifiers are double-quoted in
// the SP body — this test verifies both the SP path AND the column
// preservation by reading the row back through pgx.
//
// Test matrix:
//   - Get on missing char → 0 rows (NCSoft: ISNULL only protects existing
//     rows; absence still yields 0 rows, no synthetic (0, 0))
//   - Set fresh char → row inserted with (0, 0, 0) defaults for the three
//     non-target columns (use_bot_channel, account_id, vip_icon)
//   - Get after Set → returns (prev, current) verbatim
//   - Set existing char → only prev/current columns mutate; other
//     columns are preserved (ON CONFLICT DO UPDATE pin)
//   - Set with prev=0, current=0 → row exists; Get returns (0, 0)
//   - Char_id isolation: writing one char does not bleed to neighbours
//
// Cleanup: char_id band 9_660_001..9_660_099 (R26 batch's reserved band).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	infCharFresh    = 9660010 // never written before "Get on missing"
	infCharSet      = 9660011 // initial Set then Get round-trip
	infCharOverride = 9660012 // Set twice — verify update semantics
	infCharZero     = 9660013 // Set (0, 0) — distinguish from missing
	infCharIsoA     = 9660014 // isolation pair A
	infCharIsoB     = 9660015 // isolation pair B
)

// infCleanup wipes the R26 char_id band from user_extra_info.
// Idempotent — safe to call before AND after the test (defer pattern).
func infCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_extra_info
		  WHERE char_id BETWEEN 9660001 AND 9660099`); err != nil {
		t.Fatalf("infCleanup: %v", err)
	}
}

func TestInfinitySeasonRecord(t *testing.T) {
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

	infCleanup(t, ctx, pool)
	t.Cleanup(func() { infCleanup(t, context.Background(), pool) })

	t.Run("get on missing char returns 0 rows (no synthetic defaults)", func(t *testing.T) {
		// NCSoft pin: missing char yields 0 rows — ISNULL only fires
		// on existing rows whose prev/current columns are NULL.
		rows, err := pool.CallSP(ctx, "aion_getinfinityseasonrecord", infCharFresh)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var seen int
		for rows.Next() {
			seen++
		}
		if seen != 0 {
			t.Fatalf("missing char: got %d rows, want 0", seen)
		}
	})

	t.Run("set fresh char inserts with NCSoft default columns", func(t *testing.T) {
		// First write for infCharSet → INSERT path. The non-target
		// columns must default to NCSoft pinned literals: use_bot_channel=0,
		// account_id=0, vip_icon=0. use_bot_channel_update_date stays NULL.
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharSet, 100, 250); err != nil {
			t.Fatalf("CallSPExec set fresh: %v", err)
		}

		var useBot, vipIcon int16
		var accountID *int
		var prev, current *int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_bot_channel, account_id, vip_icon,
			        "prevSeasonReward", "currentSeasonReward"
			   FROM user_extra_info WHERE char_id = $1`,
			infCharSet).Scan(&useBot, &accountID, &vipIcon, &prev, &current); err != nil {
			t.Fatalf("verify columns: %v", err)
		}
		if useBot != 0 {
			t.Fatalf("use_bot_channel default: got %d, want 0", useBot)
		}
		if accountID == nil || *accountID != 0 {
			t.Fatalf("account_id default: got %v, want 0 (NCSoft pin)", accountID)
		}
		if vipIcon != 0 {
			t.Fatalf("vip_icon default: got %d, want 0", vipIcon)
		}
		if prev == nil || *prev != 100 {
			t.Fatalf("prev: got %v, want 100", prev)
		}
		if current == nil || *current != 250 {
			t.Fatalf("current: got %v, want 250", current)
		}
	})

	t.Run("get after set round-trips (prev, current)", func(t *testing.T) {
		var prev, current int
		if err := pool.CallSPRow(ctx, "aion_getinfinityseasonrecord",
			infCharSet).Scan(&prev, &current); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if prev != 100 || current != 250 {
			t.Fatalf("round-trip: got (%d, %d), want (100, 250)", prev, current)
		}
	})

	t.Run("set existing char only mutates prev/current; other columns preserved", func(t *testing.T) {
		// Pre-stamp use_bot_channel and vip_icon to non-zero values then
		// re-Set to verify ON CONFLICT DO UPDATE leaves them untouched.
		if _, err := pool.Inner().Exec(ctx,
			`UPDATE user_extra_info SET use_bot_channel = 7, vip_icon = 9
			  WHERE char_id = $1`, infCharOverride); err != nil {
			// First time path — insert via SP then patch the side columns.
			if err2 := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
				infCharOverride, 1, 2); err2 != nil {
				t.Fatalf("CallSPExec seed: %v", err2)
			}
			if _, err3 := pool.Inner().Exec(ctx,
				`UPDATE user_extra_info SET use_bot_channel = 7, vip_icon = 9
				  WHERE char_id = $1`, infCharOverride); err3 != nil {
				t.Fatalf("seed patch: %v", err3)
			}
		}
		// Initial seed succeeded above (or was a no-op); now ensure the
		// row exists and has the patched side columns.
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharOverride, 1, 2); err != nil {
			t.Fatalf("CallSPExec seed: %v", err)
		}
		if _, err := pool.Inner().Exec(ctx,
			`UPDATE user_extra_info SET use_bot_channel = 7, vip_icon = 9
			  WHERE char_id = $1`, infCharOverride); err != nil {
			t.Fatalf("patch side cols: %v", err)
		}

		// Now re-Set with new prev/current — side cols MUST stay 7 / 9.
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharOverride, 999, 1234); err != nil {
			t.Fatalf("CallSPExec update: %v", err)
		}
		var useBot, vipIcon int16
		var prev, current int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_bot_channel, vip_icon,
			        "prevSeasonReward", "currentSeasonReward"
			   FROM user_extra_info WHERE char_id = $1`,
			infCharOverride).Scan(&useBot, &vipIcon, &prev, &current); err != nil {
			t.Fatalf("verify preserve: %v", err)
		}
		if useBot != 7 {
			t.Fatalf("use_bot_channel mutated: got %d, want 7 (preserve pin)", useBot)
		}
		if vipIcon != 9 {
			t.Fatalf("vip_icon mutated: got %d, want 9 (preserve pin)", vipIcon)
		}
		if prev != 999 || current != 1234 {
			t.Fatalf("prev/current: got (%d, %d), want (999, 1234)", prev, current)
		}
	})

	t.Run("set zeros distinguishes from missing (row exists, returns (0,0))", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharZero, 0, 0); err != nil {
			t.Fatalf("CallSPExec set zero: %v", err)
		}
		// Get must return 1 row of (0, 0), not zero rows.
		rows, err := pool.CallSP(ctx, "aion_getinfinityseasonrecord", infCharZero)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var seen, prev, current int
		for rows.Next() {
			if err := rows.Scan(&prev, &current); err != nil {
				t.Fatalf("scan: %v", err)
			}
			seen++
		}
		if seen != 1 {
			t.Fatalf("zero-row visible: got %d rows, want 1", seen)
		}
		if prev != 0 || current != 0 {
			t.Fatalf("zero values: got (%d, %d), want (0, 0)", prev, current)
		}
	})

	t.Run("char isolation: write to A does not affect B", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharIsoA, 11, 22); err != nil {
			t.Fatalf("CallSPExec A: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharIsoB, 33, 44); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}
		// Mutate A and verify B unchanged.
		if err := pool.CallSPExec(ctx, "aion_setinfinityseasonrecord",
			infCharIsoA, 111, 222); err != nil {
			t.Fatalf("CallSPExec A update: %v", err)
		}
		var prevB, currentB int
		if err := pool.CallSPRow(ctx, "aion_getinfinityseasonrecord",
			infCharIsoB).Scan(&prevB, &currentB); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if prevB != 33 || currentB != 44 {
			t.Fatalf("B leaked: got (%d, %d), want (33, 44)", prevB, currentB)
		}
	})
}
