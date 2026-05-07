// Package database — integration test for aion_putwallet.
//
// Plain INSERT into user_wallet seeding a Quna currency row for a fresh
// character. Hard-coded name_id=18240001 (Quna namespace). Returns
// rows-affected (always 1 for a successful insert).
//
// Test matrix:
//   - first put inserts a row with name_id=18240001 and amount=0, returns 1
//   - duplicate put on same char_id ALSO inserts (T-SQL has no UNIQUE)
//   - 3 distinct chars → 3 rows
//   - neighbour char's row is NOT modified
package database

import (
	"context"
	"testing"
	"time"
)

// Sentinel char_ids well outside any real-character range.
const (
	cidPutWalletA = 9002001
	cidPutWalletB = 9002002
	cidPutWalletC = 9002003
)

func putWalletCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_wallet WHERE char_id BETWEEN 9002001 AND 9002099`); err != nil {
		t.Fatalf("putWalletCleanup user_wallet: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9002001 AND 9002099`); err != nil {
		t.Fatalf("putWalletCleanup user_data: %v", err)
	}
}

func TestPutWallet(t *testing.T) {
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

	putWalletCleanup(t, ctx, pool)
	t.Cleanup(func() { putWalletCleanup(t, context.Background(), pool) })

	// Seed parent user_data rows. user_wallet has no FK in T-SQL or our
	// port, but we mirror the cleanup-order discipline used by the rest
	// of the batch so a future FK addition is non-breaking.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidPutWalletA, "wA"},
		{cidPutWalletB, "wB"},
		{cidPutWalletC, "wC"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "pw_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first put inserts Quna row with amount=0, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putwallet", cidPutWalletA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first put: got %d, want 1", affected)
		}

		var (
			nameID int
			amount int64
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT name_id, amount FROM user_wallet WHERE char_id = $1`,
			cidPutWalletA).Scan(&nameID, &amount); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if nameID != 18240001 {
			t.Fatalf("name_id: got %d, want 18240001 (Quna namespace)", nameID)
		}
		if amount != 0 {
			t.Fatalf("amount: got %d, want 0 (fresh wallet)", amount)
		}
	})

	t.Run("duplicate put on same char_id ALSO inserts (no UNIQUE)", func(t *testing.T) {
		// T-SQL has no UNIQUE constraint on (char_id, name_id) — a replayed
		// character creation could produce dup rows. PG mirrors that bug
		// for bug. The application layer (Lua wallet helper) guards via
		// transaction in the create-character flow; SP stays a primitive.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putwallet", cidPutWalletA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow second: %v", err)
		}
		if affected != 1 {
			t.Fatalf("duplicate put: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_wallet WHERE char_id = $1`,
			cidPutWalletA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("dup rows: got %d, want 2 (T-SQL allows dup)", cnt)
		}
	})

	t.Run("3 distinct chars land as 3 rows in any order", func(t *testing.T) {
		// Wipe to clean state before this sub-test.
		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM user_wallet WHERE char_id BETWEEN 9002001 AND 9002099`); err != nil {
			t.Fatalf("inner-cleanup: %v", err)
		}

		for _, c := range []int{cidPutWalletA, cidPutWalletB, cidPutWalletC} {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putwallet", c).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow c=%d: %v", c, err)
			}
			if affected != 1 {
				t.Fatalf("put c=%d: got %d, want 1", c, affected)
			}
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_wallet WHERE char_id BETWEEN 9002001 AND 9002099`).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 3 {
			t.Fatalf("3-char rows: got %d, want 3", cnt)
		}
	})

	t.Run("neighbour char's row not modified by put on different char", func(t *testing.T) {
		// B and C were inserted in the prior sub-test. Putting A again
		// must not touch them.
		var beforeB, beforeC int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE char_id = $1`,
			cidPutWalletB).Scan(&beforeB); err != nil {
			t.Fatalf("read B: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE char_id = $1`,
			cidPutWalletC).Scan(&beforeC); err != nil {
			t.Fatalf("read C: %v", err)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_putwallet", cidPutWalletA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow neighbour-isolation: %v", err)
		}
		if affected != 1 {
			t.Fatalf("put A: got %d, want 1", affected)
		}

		var afterB, afterC int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE char_id = $1`,
			cidPutWalletB).Scan(&afterB); err != nil {
			t.Fatalf("read B after: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_wallet WHERE char_id = $1`,
			cidPutWalletC).Scan(&afterC); err != nil {
			t.Fatalf("read C after: %v", err)
		}
		if afterB != beforeB || afterC != beforeC {
			t.Fatalf("neighbour leak: B %d→%d, C %d→%d", beforeB, afterB, beforeC, afterC)
		}
	})
}
