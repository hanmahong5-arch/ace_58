// Package database — integration test for aion_addwalletamount.
//
// Pure UPDATE on user_wallet keyed by surrogate `id`: amount = amount + delta.
// Returns rows-affected so the caller can detect "row id unknown" (0) vs
// "delta committed" (1).
//
// Test matrix:
//   - positive delta increments correctly
//   - negative delta decrements correctly (allowed to go negative — caller
//     gates this)
//   - two sequential adds compound (atomic at row level)
//   - unknown id returns 0 and creates no row
//   - neighbour wallet row at different id is NOT modified
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAddWalletA = 9002101 // primary target
	cidAddWalletB = 9002102 // neighbour
)

func addWalletAmountCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_wallet WHERE char_id BETWEEN 9002101 AND 9002199`); err != nil {
		t.Fatalf("addWalletAmountCleanup user_wallet: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9002101 AND 9002199`); err != nil {
		t.Fatalf("addWalletAmountCleanup user_data: %v", err)
	}
}

func TestAddWalletAmount(t *testing.T) {
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

	addWalletAmountCleanup(t, ctx, pool)
	t.Cleanup(func() { addWalletAmountCleanup(t, context.Background(), pool) })

	// Seed parents.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidAddWalletA, "awA"},
		{cidAddWalletB, "awB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "aw_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Seed two wallet rows directly (bypass 00189 to keep this test focused
	// on AddWalletAmount semantics). Capture the surrogate id of each.
	var idA, idB int64
	if err := pool.Inner().QueryRow(ctx,
		`INSERT INTO user_wallet(char_id, name_id, amount) VALUES ($1, $2, $3) RETURNING id`,
		cidAddWalletA, 18240001, int64(1000)).Scan(&idA); err != nil {
		t.Fatalf("seed walletA: %v", err)
	}
	if err := pool.Inner().QueryRow(ctx,
		`INSERT INTO user_wallet(char_id, name_id, amount) VALUES ($1, $2, $3) RETURNING id`,
		cidAddWalletB, 18240001, int64(500)).Scan(&idB); err != nil {
		t.Fatalf("seed walletB: %v", err)
	}

	t.Run("positive delta increments and returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addwalletamount", idA, int64(250)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE id = $1`, idA).Scan(&amount); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amount != 1250 {
			t.Fatalf("amount after +250: got %d, want 1250 (1000 + 250)", amount)
		}
	})

	t.Run("second positive delta compounds", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addwalletamount", idA, int64(50)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE id = $1`, idA).Scan(&amount); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amount != 1300 {
			t.Fatalf("amount after +50: got %d, want 1300 (1250 + 50)", amount)
		}
	})

	t.Run("negative delta decrements (no balance gating in SP)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addwalletamount", idA, int64(-300)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE id = $1`, idA).Scan(&amount); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amount != 1000 {
			t.Fatalf("amount after -300: got %d, want 1000 (1300 - 300)", amount)
		}
	})

	t.Run("delta beyond balance is allowed (negative balance, caller gates)", func(t *testing.T) {
		// SP is a dumb arithmetic primitive — overflow / underflow checks
		// belong to the Lua wallet helper. We assert the bug-for-bug
		// behaviour: negative balance is observable.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addwalletamount", idA, int64(-5000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE id = $1`, idA).Scan(&amount); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amount != -4000 {
			t.Fatalf("amount after -5000: got %d, want -4000 (1000 - 5000)", amount)
		}
	})

	t.Run("unknown id returns 0 and creates no row", func(t *testing.T) {
		// Pick a sentinel id far above any BIGSERIAL we could realistically
		// have produced. Even on a long-lived test DB, 9_999_999_999 is
		// safe.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addwalletamount", int64(9999999999), int64(100)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("unknown id: got %d, want 0", affected)
		}

		// No phantom row.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_wallet WHERE id = $1`,
			int64(9999999999)).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("phantom row: got %d, want 0", cnt)
		}
	})

	t.Run("neighbour wallet B not affected by all those A mutations", func(t *testing.T) {
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE id = $1`, idB).Scan(&amount); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if amount != 500 {
			t.Fatalf("B leak: got amount=%d, want 500 (untouched seed)", amount)
		}
	})
}
