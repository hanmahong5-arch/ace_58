// Package database — integration tests for aion_GetBindPoint / aion_SetBindPoint.
//
// These two SPs are not in the NCSoft dump; they expose user_data.last_normal_*
// to Lua callers (instance.leave teleport, S-19 crash-recovery guard, cm_revive)
// so a phantom-instance crash never strands the player and a normal-world death
// always rebirths in the right map.
//
// Convention follows sp_pve_round*_test.go: env-gated via testDSN(), Skip() on
// missing PG, dedicated cleanup band so the test is independent.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	bindCharMissing = 9000799 // never inserted — tests "no row" path
	bindCharLive    = 9000700 // baseline char with default last_normal_*
	bindCharDeleted = 9000701 // soft-deleted (delete_date != 0)
)

func bindPointCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9000700 AND 9000799`); err != nil {
		t.Fatalf("bindPointCleanup: %v", err)
	}
}

func TestBindPoint_GetSetRoundtrip(t *testing.T) {
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

	bindPointCleanup(t, ctx, pool)
	t.Cleanup(func() { bindPointCleanup(t, context.Background(), pool) })

	// Seed: live char + soft-deleted char.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'BindLive', 'bptest_live')`,
		bindCharLive); err != nil {
		t.Fatalf("seed live: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, delete_date)
		 VALUES ($1, 'BindGhost', 'bptest_ghost', 1700000000)`,
		bindCharDeleted); err != nil {
		t.Fatalf("seed deleted: %v", err)
	}

	t.Run("GetBindPoint missing char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getbindpoint", bindCharMissing)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing char: got %d rows, want 0", n)
		}
	})

	t.Run("GetBindPoint live char with defaults returns origin row", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getbindpoint", bindCharLive)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n             int
			world         int
			x, y, z       float32
			dir           int16
		)
		for rows.Next() {
			if err := rows.Scan(&world, &x, &y, &z, &dir); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("live char: got %d rows, want 1", n)
		}
		// Defaults from scaffold round 3 are all zero.
		if world != 0 || x != 0 || y != 0 || z != 0 || dir != 0 {
			t.Fatalf("default bind: world=%d xyz=(%v,%v,%v) dir=%d (want all zero)",
				world, x, y, z, dir)
		}
	})

	t.Run("GetBindPoint soft-deleted char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getbindpoint", bindCharDeleted)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("soft-deleted char: got %d rows, want 0 (delete_date filter)", n)
		}
	})

	t.Run("SetBindPoint on missing char returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbindpoint",
			bindCharMissing, 210010000, float32(100.0), float32(200.0), float32(300.0), int16(64),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing char: affected=%d, want 0", affected)
		}
	})

	t.Run("SetBindPoint on soft-deleted char returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbindpoint",
			bindCharDeleted, 210010000, float32(1.0), float32(2.0), float32(3.0), int16(0),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("soft-deleted char: affected=%d, want 0", affected)
		}
	})

	t.Run("Set then Get reflects new bind", func(t *testing.T) {
		const (
			wantWorld     = 210010000
			wantX float32 = 1234.5
			wantY float32 = 5678.25
			wantZ float32 = 410.125
			wantD int16   = 96
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbindpoint",
			bindCharLive, wantWorld, wantX, wantY, wantZ, wantD,
		).Scan(&affected); err != nil {
			t.Fatalf("Set: %v", err)
		}
		if affected != 1 {
			t.Fatalf("Set: affected=%d, want 1", affected)
		}

		rows, err := pool.CallSP(ctx, "aion_getbindpoint", bindCharLive)
		if err != nil {
			t.Fatalf("Get: %v", err)
		}
		defer rows.Close()
		var (
			n       int
			world   int
			x, y, z float32
			dir     int16
		)
		for rows.Next() {
			if err := rows.Scan(&world, &x, &y, &z, &dir); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("Get after Set: got %d rows, want 1", n)
		}
		if world != wantWorld || x != wantX || y != wantY || z != wantZ || dir != wantD {
			t.Fatalf("Get after Set: world=%d xyz=(%v,%v,%v) dir=%d, want world=%d xyz=(%v,%v,%v) dir=%d",
				world, x, y, z, dir, wantWorld, wantX, wantY, wantZ, wantD)
		}
	})
}
