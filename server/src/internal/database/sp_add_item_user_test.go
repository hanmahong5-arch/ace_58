// Package database — integration test for aion_AddItemUser, the 3-param
// convenience wrapper over aion_PutItem_20150921 used by starter_kit.lua and
// the player.add_item Lua API.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAddItemLive = 9001000
	cidAddItemFree = 9001001
)

func addItemUserCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	stmts := []string{
		`DELETE FROM user_item_attribute WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9001000 AND 9001099)`,
		`DELETE FROM user_item_polish    WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9001000 AND 9001099)`,
		`DELETE FROM user_item_charge    WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9001000 AND 9001099)`,
		`DELETE FROM user_item_option    WHERE char_id BETWEEN 9001000 AND 9001099`,
		`DELETE FROM user_item           WHERE char_id BETWEEN 9001000 AND 9001099`,
		`DELETE FROM user_data           WHERE char_id BETWEEN 9001000 AND 9001099`,
	}
	for _, s := range stmts {
		if _, err := p.Inner().Exec(ctx, s); err != nil {
			t.Fatalf("addItemUserCleanup %q: %v", s, err)
		}
	}
}

func TestAddItemUser(t *testing.T) {
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

	addItemUserCleanup(t, ctx, pool)
	t.Cleanup(func() { addItemUserCleanup(t, context.Background(), pool) })

	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'AddItemTester', 'aiu_live')`,
		cidAddItemLive); err != nil {
		t.Fatalf("seed live: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'StackHero', 'aiu_free')`,
		cidAddItemFree); err != nil {
		t.Fatalf("seed free: %v", err)
	}

	t.Run("happy path: insert + verify row", func(t *testing.T) {
		var newID int64
		if err := pool.CallSPRow(ctx, "aion_additemuser",
			cidAddItemLive, 110000001, int64(1)).Scan(&newID); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if newID <= 0 {
			t.Fatalf("returned id=%d, want > 0", newID)
		}

		var nameID int
		var amount int64
		var warehouse int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT name_id, amount, warehouse FROM user_item WHERE id = $1`,
			newID).Scan(&nameID, &amount, &warehouse); err != nil {
			t.Fatalf("verify row: %v", err)
		}
		if nameID != 110000001 || amount != 1 || warehouse != 0 {
			t.Fatalf("row contents: name_id=%d amount=%d warehouse=%d, want 110000001/1/0",
				nameID, amount, warehouse)
		}
	})

	t.Run("count > 1 stacks via amount column", func(t *testing.T) {
		var newID int64
		if err := pool.CallSPRow(ctx, "aion_additemuser",
			cidAddItemLive, 100000001, int64(99)).Scan(&newID); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_item WHERE id = $1`, newID).Scan(&amount); err != nil {
			t.Fatalf("verify amount: %v", err)
		}
		if amount != 99 {
			t.Fatalf("stack: amount=%d, want 99", amount)
		}
	})

	t.Run("count <= 0 defaults to 1 (defensive)", func(t *testing.T) {
		var newID int64
		// Caller passes 0 from a defaulted table field → expect amount=1, not 0.
		if err := pool.CallSPRow(ctx, "aion_additemuser",
			cidAddItemFree, 100000002, int64(0)).Scan(&newID); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		var amount int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT amount FROM user_item WHERE id = $1`, newID).Scan(&amount); err != nil {
			t.Fatalf("verify amount: %v", err)
		}
		if amount != 1 {
			t.Fatalf("zero-count default: amount=%d, want 1", amount)
		}
	})

	t.Run("multiple grants produce distinct ids (starter-kit invariant)", func(t *testing.T) {
		var id1, id2, id3 int64
		if err := pool.CallSPRow(ctx, "aion_additemuser",
			cidAddItemFree, 110000003, int64(1)).Scan(&id1); err != nil {
			t.Fatalf("grant 1: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_additemuser",
			cidAddItemFree, 110000004, int64(1)).Scan(&id2); err != nil {
			t.Fatalf("grant 2: %v", err)
		}
		if err := pool.CallSPRow(ctx, "aion_additemuser",
			cidAddItemFree, 110000005, int64(1)).Scan(&id3); err != nil {
			t.Fatalf("grant 3: %v", err)
		}
		if id1 == id2 || id2 == id3 || id1 == id3 {
			t.Fatalf("ids not distinct: %d %d %d", id1, id2, id3)
		}
	})
}
