// Package database — integration test for aion_AddItemAmount.
//
// Two-statement protocol: (1) UPDATE amount += delta; (2) if delta < 0 AND
// post-update amount <= 0 AND name_id != 182400001 (Kinah), sweep row to
// warehouse=10 (trash bin). Returns rows-affected from the FIRST UPDATE.
//
// Test matrix:
//   - happy increment + decrement
//   - decrement to exactly 0 → swept to warehouse 10
//   - Kinah decrement to 0 → NOT swept (wallet exception)
//   - unknown id returns 0
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAddItemAmount = 9001600
)

func addItemAmountCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	stmts := []string{
		`DELETE FROM user_item_attribute WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9001600 AND 9001699)`,
		`DELETE FROM user_item_polish    WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9001600 AND 9001699)`,
		`DELETE FROM user_item_charge    WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9001600 AND 9001699)`,
		`DELETE FROM user_item_option    WHERE char_id BETWEEN 9001600 AND 9001699`,
		`DELETE FROM user_item           WHERE char_id BETWEEN 9001600 AND 9001699`,
		`DELETE FROM user_data           WHERE char_id BETWEEN 9001600 AND 9001699`,
	}
	for _, s := range stmts {
		if _, err := p.Inner().Exec(ctx, s); err != nil {
			t.Fatalf("addItemAmountCleanup %q: %v", s, err)
		}
	}
}

// seedItem inserts a user_item row directly (bypassing aion_putitem) so the
// test stays focused on AddItemAmount semantics. Returns the new id.
func seedItem(t *testing.T, ctx context.Context, p *Pool, charID, nameID int, amount int64) int64 {
	t.Helper()
	var id int64
	if err := p.Inner().QueryRow(ctx,
		`INSERT INTO user_item(char_id, name_id, amount, warehouse) VALUES ($1, $2, $3, 0) RETURNING id`,
		charID, nameID, amount).Scan(&id); err != nil {
		t.Fatalf("seedItem: %v", err)
	}
	return id
}

func TestAddItemAmount(t *testing.T) {
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

	addItemAmountCleanup(t, ctx, pool)
	t.Cleanup(func() { addItemAmountCleanup(t, context.Background(), pool) })

	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'AmtHero', 'aia_owner')`,
		cidAddItemAmount); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	t.Run("positive delta increments amount, no sweep", func(t *testing.T) {
		id := seedItem(t, ctx, pool, cidAddItemAmount, 100000010, 5)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_additemamount", id, int64(7)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected=%d, want 1", affected)
		}
		var amt int64
		var wh int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount, warehouse FROM user_item WHERE id = $1`, id).Scan(&amt, &wh); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amt != 12 || wh != 0 {
			t.Fatalf("post inc: amount=%d wh=%d, want 12/0", amt, wh)
		}
	})

	t.Run("negative delta resulting in positive amount stays in inventory", func(t *testing.T) {
		id := seedItem(t, ctx, pool, cidAddItemAmount, 100000011, 10)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_additemamount", id, int64(-3)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected=%d, want 1", affected)
		}
		var amt int64
		var wh int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount, warehouse FROM user_item WHERE id = $1`, id).Scan(&amt, &wh); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amt != 7 || wh != 0 {
			t.Fatalf("post dec: amount=%d wh=%d, want 7/0 (no sweep)", amt, wh)
		}
	})

	t.Run("decrement to zero sweeps non-Kinah row to warehouse 10", func(t *testing.T) {
		id := seedItem(t, ctx, pool, cidAddItemAmount, 100000012, 4)
		if err := pool.CallSPRow(ctx, "aion_additemamount", id, int64(-4)).Scan(new(int)); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		var amt int64
		var wh int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount, warehouse FROM user_item WHERE id = $1`, id).Scan(&amt, &wh); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amt != 0 || wh != 10 {
			t.Fatalf("post drain: amount=%d wh=%d, want 0/10 (sweep to bin)", amt, wh)
		}
	})

	t.Run("Kinah decrement to zero is NOT swept (wallet exception)", func(t *testing.T) {
		// 182400001 is Kinah's name_id; balance can hit zero without trashing.
		id := seedItem(t, ctx, pool, cidAddItemAmount, 182400001, 1000)
		if err := pool.CallSPRow(ctx, "aion_additemamount", id, int64(-1000)).Scan(new(int)); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		var amt int64
		var wh int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount, warehouse FROM user_item WHERE id = $1`, id).Scan(&amt, &wh); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if amt != 0 || wh != 0 {
			t.Fatalf("Kinah drain: amount=%d wh=%d, want 0/0 (wallet survives)", amt, wh)
		}
	})

	t.Run("unknown id returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_additemamount", int64(99999999999), int64(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("affected=%d, want 0", affected)
		}
	})
}
