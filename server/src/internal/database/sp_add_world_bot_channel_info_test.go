// Package database — integration test for aion_AddWorldBotChannelInfo.
//
// Bug-for-bug NCSoft semantics: IF row exists UPDATE world_id, THEN
// unconditionally INSERT a new row. Compounds duplicates on repeated
// calls (see 00192 schema notes).
//
// Test matrix:
//   - first call (no row): INSERT only → 1 row
//   - second call (row exists): UPDATE + INSERT → 2 rows, both at new world_id
//   - third call: 3 rows total, all at the latest world_id
//   - neighbour char_id at the same time is unaffected
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidWBotA   = 9002201 // primary target
	cidWBotB   = 9002202 // neighbour
	wbotAcctA  = 5550001
	wbotAcctB  = 5550002
	wbotWorld1 = 130100000 // first call's world_id
	wbotWorld2 = 130200000 // second call's world_id (post-UPDATE branch)
	wbotWorld3 = 130300000 // third call
)

func addWorldBotChannelInfoCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM world_bot_channel_info WHERE char_id BETWEEN 9002201 AND 9002299`); err != nil {
		t.Fatalf("addWorldBotChannelInfoCleanup world_bot_channel_info: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9002201 AND 9002299`); err != nil {
		t.Fatalf("addWorldBotChannelInfoCleanup user_data: %v", err)
	}
}

func TestAddWorldBotChannelInfo(t *testing.T) {
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

	addWorldBotChannelInfoCleanup(t, ctx, pool)
	t.Cleanup(func() { addWorldBotChannelInfoCleanup(t, context.Background(), pool) })

	// Seed parents — world_bot_channel_info has no FK in T-SQL, but we
	// keep cleanup-order consistent with the rest of the batch.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidWBotA, "wbA"},
		{cidWBotB, "wbB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "wb_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first call inserts 1 row at world1, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addworldbotchannelinfo",
			cidWBotA, wbotAcctA, wbotWorld1).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first call: got %d, want 1", affected)
		}

		var (
			cnt              int
			account, worldID int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1`,
			cidWBotA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rows after first: got %d, want 1", cnt)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT account_id, world_id FROM world_bot_channel_info WHERE char_id = $1`,
			cidWBotA).Scan(&account, &worldID); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if account != wbotAcctA || worldID != wbotWorld1 {
			t.Fatalf("first values: got account=%d world=%d, want %d / %d",
				account, worldID, wbotAcctA, wbotWorld1)
		}
	})

	t.Run("second call: UPDATE existing world_id THEN INSERT new row → 2 rows at world2", func(t *testing.T) {
		// Bug-for-bug NCSoft: the IF EXISTS branch updates the existing
		// row's world_id, then the unconditional INSERT adds a new row
		// also at world_id=world2. Both rows end up at world2.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addworldbotchannelinfo",
			cidWBotA, wbotAcctA, wbotWorld2).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second call: got %d, want 1 (insert affects 1)", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1`,
			cidWBotA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("rows after second: got %d, want 2 (UPDATE + INSERT compound)", cnt)
		}

		// All rows at world_id=world2 — the UPDATE rewrote the original.
		var sameCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1 AND world_id = $2`,
			cidWBotA, wbotWorld2).Scan(&sameCnt); err != nil {
			t.Fatalf("count world2: %v", err)
		}
		if sameCnt != 2 {
			t.Fatalf("world2 rows: got %d, want 2", sameCnt)
		}

		// No row left at world1 — UPDATE rewrote it.
		var oldCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1 AND world_id = $2`,
			cidWBotA, wbotWorld1).Scan(&oldCnt); err != nil {
			t.Fatalf("count world1: %v", err)
		}
		if oldCnt != 0 {
			t.Fatalf("world1 leak: got %d, want 0 (UPDATE should have rewritten)", oldCnt)
		}
	})

	t.Run("third call: 3 rows total, all at world3", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addworldbotchannelinfo",
			cidWBotA, wbotAcctA, wbotWorld3).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("third call: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1`,
			cidWBotA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 3 {
			t.Fatalf("rows after third: got %d, want 3", cnt)
		}

		// All at world3 — UPDATE rewrote the prior 2 rows; INSERT added a third.
		var w3Cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1 AND world_id = $2`,
			cidWBotA, wbotWorld3).Scan(&w3Cnt); err != nil {
			t.Fatalf("count world3: %v", err)
		}
		if w3Cnt != 3 {
			t.Fatalf("world3 rows: got %d, want 3", w3Cnt)
		}
	})

	t.Run("neighbour char_id is unaffected by all of A's churn", func(t *testing.T) {
		// First, give B a clean single row.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_addworldbotchannelinfo",
			cidWBotB, wbotAcctB, wbotWorld1).Scan(&affected); err != nil {
			t.Fatalf("seed B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("seed B: got %d, want 1", affected)
		}

		// Now perturb A and verify B is untouched.
		if err := pool.CallSPRow(ctx, "aion_addworldbotchannelinfo",
			cidWBotA, wbotAcctA, wbotWorld2).Scan(&affected); err != nil {
			t.Fatalf("perturb A: %v", err)
		}
		if affected != 1 {
			t.Fatalf("perturb A: got %d, want 1", affected)
		}

		var (
			cntB     int
			worldIDB int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM world_bot_channel_info WHERE char_id = $1`,
			cidWBotB).Scan(&cntB); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if cntB != 1 {
			t.Fatalf("B row count: got %d, want 1 (untouched by A churn)", cntB)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT world_id FROM world_bot_channel_info WHERE char_id = $1`,
			cidWBotB).Scan(&worldIDB); err != nil {
			t.Fatalf("read B world: %v", err)
		}
		if worldIDB != wbotWorld1 {
			t.Fatalf("B world drift: got %d, want %d", worldIDB, wbotWorld1)
		}
	})
}
