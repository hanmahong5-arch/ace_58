// Package database — integration test for aion_SetBingoLoginTime.
//
// Naked UPDATE on user_app_installation.login_time keyed by char_id. NCSoft
// has no INSERT-on-missing-row branch — the row is born from PutCanMakeSticker
// (00091) at sticker-shop entry time. Bug-for-bug pinned: missing row → 0
// rows affected, no error.
//
// Test matrix:
//   - happy path: existing row → login_time updated, returns 1
//   - rebind: second call with new value → updates in place, still 1
//   - missing row: silent no-op, returns 0 (no INSERT)
//   - neighbour isolation: A's update doesn't perturb B
//   - boundary: login_time=0 (epoch) accepted as valid value
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidBLT_A       = 9520011
	cidBLT_B       = 9520012
	cidBLT_Missing = 9520013 // user_app_installation row intentionally absent
)

func setBingoLoginTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_app_installation WHERE char_id BETWEEN 9520011 AND 9520099`); err != nil {
		t.Fatalf("setBingoLoginTimeCleanup user_app_installation: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9520011 AND 9520099`); err != nil {
		t.Fatalf("setBingoLoginTimeCleanup user_data: %v", err)
	}
}

func TestSetBingoLoginTime(t *testing.T) {
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

	setBingoLoginTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { setBingoLoginTimeCleanup(t, context.Background(), pool) })

	// Seed parent + app_installation rows for A & B; deliberately skip the
	// app_installation row for cidBLT_Missing to test the no-op branch.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidBLT_A, "BltA"},
		{cidBLT_B, "BltB"},
		{cidBLT_Missing, "BltMissing"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "blt_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}
	for _, id := range []int{cidBLT_A, cidBLT_B} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_app_installation(char_id, can_make_sticker, login_time)
			 VALUES ($1, 0, 0)`, id); err != nil {
			t.Fatalf("seed app_installation %d: %v", id, err)
		}
	}

	t.Run("happy path: existing row updated, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbingologintime",
			cidBLT_A, int32(1700000123)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var lt int32
		if err := pool.Inner().QueryRow(ctx,
			`SELECT login_time FROM user_app_installation WHERE char_id = $1`,
			cidBLT_A).Scan(&lt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if lt != 1700000123 {
			t.Fatalf("login_time: got %d, want 1700000123", lt)
		}
	})

	t.Run("rebind: second call updates in place, still returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbingologintime",
			cidBLT_A, int32(1800000999)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow rebind: %v", err)
		}
		if affected != 1 {
			t.Fatalf("rebind: got %d, want 1", affected)
		}

		// Exactly one row must remain for char A.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_app_installation WHERE char_id = $1`,
			cidBLT_A).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rebind cnt: got %d, want 1", cnt)
		}

		var lt int32
		if err := pool.Inner().QueryRow(ctx,
			`SELECT login_time FROM user_app_installation WHERE char_id = $1`,
			cidBLT_A).Scan(&lt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if lt != 1800000999 {
			t.Fatalf("rebind value: got %d, want 1800000999", lt)
		}
	})

	t.Run("missing row: silent no-op, returns 0 (no INSERT)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbingologintime",
			cidBLT_Missing, int32(1700000000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing affected: got %d, want 0 (bug-for-bug no-INSERT)", affected)
		}

		// Confirm the SP didn't accidentally INSERT.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_app_installation WHERE char_id = $1`,
			cidBLT_Missing).Scan(&cnt); err != nil {
			t.Fatalf("count missing: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("missing accidentally inserted: got %d rows, want 0", cnt)
		}
	})

	t.Run("neighbour isolation: A's set doesn't perturb B", func(t *testing.T) {
		// Bump B independently — A must still hold the rebind value.
		if err := pool.CallSPExec(ctx, "aion_setbingologintime",
			cidBLT_B, int32(1234567890)); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}

		var aLT, bLT int32
		if err := pool.Inner().QueryRow(ctx,
			`SELECT login_time FROM user_app_installation WHERE char_id = $1`,
			cidBLT_A).Scan(&aLT); err != nil {
			t.Fatalf("verify A: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT login_time FROM user_app_installation WHERE char_id = $1`,
			cidBLT_B).Scan(&bLT); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if aLT != 1800000999 {
			t.Fatalf("A leaked from B: A=%d, want 1800000999", aLT)
		}
		if bLT != 1234567890 {
			t.Fatalf("B value: got %d, want 1234567890", bLT)
		}
	})

	t.Run("boundary: login_time=0 accepted as valid value", func(t *testing.T) {
		// Pre-condition: A has 1800000999 from an earlier subtest. Setting
		// to 0 must succeed (0 is a valid epoch / "unknown" sentinel).
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setbingologintime",
			cidBLT_A, int32(0)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow zero: %v", err)
		}
		if affected != 1 {
			t.Fatalf("zero: got %d, want 1", affected)
		}

		var lt int32
		if err := pool.Inner().QueryRow(ctx,
			`SELECT login_time FROM user_app_installation WHERE char_id = $1`,
			cidBLT_A).Scan(&lt); err != nil {
			t.Fatalf("verify zero: %v", err)
		}
		if lt != 0 {
			t.Fatalf("zero value: got %d, want 0", lt)
		}
	})
}
