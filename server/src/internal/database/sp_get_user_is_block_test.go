// Package database — integration test for aion_GetUserIsBlock.
//
// Resolve a target by user_id within the viewer's race, then report whether
// the target has the viewer on their block list, and surface the target's
// optionflags. Always emits exactly one row.
//
// Verifies: same-race target with no block → (target_id, 0, optionflags),
// same-race target who blocked viewer → (target_id, 1, optionflags),
// cross-race target → (0, 0, 0) (race wall),
// soft-deleted target → (0, 0, 0),
// missing viewer → (0, 0, 0) (viewer_race is NULL → race-match fails),
// unknown target name → (0, 0, 0).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidIBViewerElyos   = 9001400 // race=1 (Elyos)
	cidIBViewerAsmo    = 9001401 // race=2 (Asmodian)
	cidIBViewerMissing = 9001499 // never inserted

	cidIBTargetSameRaceClean   = 9001410 // Elyos, no block, optionflags=0
	cidIBTargetSameRaceBlocked = 9001411 // Elyos, has viewer in block list, optionflags=42
	cidIBTargetCrossRace       = 9001412 // Asmo (cross-race for cidIBViewerElyos)
	cidIBTargetDeleted         = 9001413 // Elyos, soft-deleted

	uidTargetClean   = "ib_t_clean"
	uidTargetBlocked = "ib_t_blocked"
	uidTargetCross   = "ib_t_cross"
	uidTargetDeleted = "ib_t_deleted"
	uidUnknown       = "ib_t_nobody_here"
)

func userIsBlockCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_block WHERE char_id BETWEEN 9001400 AND 9001499
		    OR block_id BETWEEN 9001400 AND 9001499`); err != nil {
		t.Fatalf("userIsBlockCleanup user_block: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001400 AND 9001499`); err != nil {
		t.Fatalf("userIsBlockCleanup user_data: %v", err)
	}
}

func TestGetUserIsBlock(t *testing.T) {
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

	userIsBlockCleanup(t, ctx, pool)
	t.Cleanup(func() { userIsBlockCleanup(t, context.Background(), pool) })

	// Viewers.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, race) VALUES ($1, 'ViewerElyos', 'ib_v_elyos', 1)`,
		cidIBViewerElyos); err != nil {
		t.Fatalf("seed viewer elyos: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, race) VALUES ($1, 'ViewerAsmo', 'ib_v_asmo', 2)`,
		cidIBViewerAsmo); err != nil {
		t.Fatalf("seed viewer asmo: %v", err)
	}

	// Same-race targets (Elyos).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, race, optionflags)
		 VALUES ($1, 'TgtClean', $2, 1, 0)`,
		cidIBTargetSameRaceClean, uidTargetClean); err != nil {
		t.Fatalf("seed target clean: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, race, optionflags)
		 VALUES ($1, 'TgtBlocked', $2, 1, 42)`,
		cidIBTargetSameRaceBlocked, uidTargetBlocked); err != nil {
		t.Fatalf("seed target blocked: %v", err)
	}
	// Target-blocked has viewer (Elyos) in their block list.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_block(char_id, block_id, comment)
		 VALUES ($1, $2, 'block-comment')`,
		cidIBTargetSameRaceBlocked, cidIBViewerElyos); err != nil {
		t.Fatalf("seed user_block: %v", err)
	}

	// Cross-race target (Asmo).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, race, optionflags)
		 VALUES ($1, 'TgtCross', $2, 2, 99)`,
		cidIBTargetCrossRace, uidTargetCross); err != nil {
		t.Fatalf("seed target cross: %v", err)
	}

	// Soft-deleted target (same race as viewer).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, race, optionflags, delete_date)
		 VALUES ($1, 'TgtDeleted', $2, 1, 7, 1700000000)`,
		cidIBTargetDeleted, uidTargetDeleted); err != nil {
		t.Fatalf("seed target deleted: %v", err)
	}

	t.Run("same-race clean target → (target_id, 0, optionflags=0)", func(t *testing.T) {
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerElyos, uidTargetClean).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != cidIBTargetSameRaceClean || blk != 0 || opt != 0 {
			t.Fatalf("clean: tgt=%d block=%d opt=%d, want %d/0/0",
				tgt, blk, opt, cidIBTargetSameRaceClean)
		}
	})

	t.Run("same-race target who blocked viewer → (target_id, 1, optionflags)", func(t *testing.T) {
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerElyos, uidTargetBlocked).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != cidIBTargetSameRaceBlocked || blk != 1 || opt != 42 {
			t.Fatalf("blocked: tgt=%d block=%d opt=%d, want %d/1/42",
				tgt, blk, opt, cidIBTargetSameRaceBlocked)
		}
	})

	t.Run("cross-race target → (0, 0, 0)", func(t *testing.T) {
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerElyos, uidTargetCross).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != 0 || blk != 0 || opt != 0 {
			t.Fatalf("cross-race: tgt=%d block=%d opt=%d, want 0/0/0", tgt, blk, opt)
		}
	})

	t.Run("soft-deleted target → (0, 0, 0)", func(t *testing.T) {
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerElyos, uidTargetDeleted).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != 0 || blk != 0 || opt != 0 {
			t.Fatalf("soft-deleted: tgt=%d block=%d opt=%d, want 0/0/0", tgt, blk, opt)
		}
	})

	t.Run("missing viewer → (0, 0, 0) (race-wall blocks)", func(t *testing.T) {
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerMissing, uidTargetClean).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != 0 || blk != 0 || opt != 0 {
			t.Fatalf("missing viewer: tgt=%d block=%d opt=%d, want 0/0/0", tgt, blk, opt)
		}
	})

	t.Run("unknown target name → (0, 0, 0)", func(t *testing.T) {
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerElyos, uidUnknown).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != 0 || blk != 0 || opt != 0 {
			t.Fatalf("unknown: tgt=%d block=%d opt=%d, want 0/0/0", tgt, blk, opt)
		}
	})

	t.Run("Asmo viewer can resolve a different Asmo target", func(t *testing.T) {
		// Cross-race target was Asmo; for the Asmo viewer it's same-race.
		var tgt, blk, opt int
		if err := pool.CallSPRow(ctx, "aion_getuserisblock",
			cidIBViewerAsmo, uidTargetCross).Scan(&tgt, &blk, &opt); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if tgt != cidIBTargetCrossRace || blk != 0 || opt != 99 {
			t.Fatalf("asmo→asmo: tgt=%d block=%d opt=%d, want %d/0/99",
				tgt, blk, opt, cidIBTargetCrossRace)
		}
	})
}
