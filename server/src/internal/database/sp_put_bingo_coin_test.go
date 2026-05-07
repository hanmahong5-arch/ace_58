// Package database — integration test for aion_PutBingoCoin.
//
// Pure INSERT into user_bingo (append-only audit log of bingo coin grants).
// No UNIQUE on any tuple — same (guid, bingo_type, bingo_nameid) can recur
// in rapid succession (replay = independent evidence).
//
// Test matrix:
//   - first put inserts 1 row, returns 1
//   - 4 puts on same guid → 4 rows in PK (id) order
//   - duplicate put (same all-args) ALSO inserts (no UNIQUE)
//   - neighbour isolation: A's puts don't appear under B's guid
//   - log persists past parent char deletion (no FK — audit survives)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidBingoA       = 9520001 // owner with multiple bingo grants
	cidBingoB       = 9520002 // neighbour-isolation peer
	cidBingoOrphan  = 9520003 // we'll log then "delete the parent"
	bingoAccountA   = 8520001
	bingoAccountB   = 8520002
)

func putBingoCoinCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_bingo WHERE guid BETWEEN 9520001 AND 9520099`); err != nil {
		t.Fatalf("putBingoCoinCleanup user_bingo: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9520001 AND 9520099`); err != nil {
		t.Fatalf("putBingoCoinCleanup user_data: %v", err)
	}
}

func TestPutBingoCoin(t *testing.T) {
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

	putBingoCoinCleanup(t, ctx, pool)
	t.Cleanup(func() { putBingoCoinCleanup(t, context.Background(), pool) })

	// Seed parent char rows (PutBingoCoin doesn't FK-check, but we want a
	// realistic flow + a clean cleanup band).
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidBingoA, "BingoA"},
		{cidBingoB, "BingoB"},
		{cidBingoOrphan, "BingoOrphan"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "bingo_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first put inserts 1 row, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putbingocoin",
			cidBingoA, int16(1), int32(2001), int16(0), int32(bingoAccountA), int16(5),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first: got %d, want 1", affected)
		}

		var (
			cnt    int
			amount int16
			status int16
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*), COALESCE(MAX(amount), 0), COALESCE(MAX(status), 0)
			   FROM user_bingo WHERE guid = $1`, cidBingoA).Scan(&cnt, &amount, &status); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cnt != 1 || amount != 5 || status != 0 {
			t.Fatalf("first row: got cnt=%d amount=%d status=%d, want 1/5/0", cnt, amount, status)
		}
	})

	t.Run("4 puts on same guid → 4 rows", func(t *testing.T) {
		// Wipe to isolate this case.
		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM user_bingo WHERE guid = $1`, cidBingoA); err != nil {
			t.Fatalf("inner-cleanup: %v", err)
		}

		grants := []struct {
			btype  int16
			nameid int32
			status int16
			amt    int16
		}{
			{1, 2001, 0, 5},
			{1, 2002, 0, 7},
			{2, 3001, 1, 3},
			{2, 3002, 2, 1},
		}
		for _, g := range grants {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putbingocoin",
				cidBingoA, g.btype, g.nameid, g.status, int32(bingoAccountA), g.amt,
			).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow nameid=%d: %v", g.nameid, err)
			}
			if affected != 1 {
				t.Fatalf("nameid=%d: got %d, want 1", g.nameid, affected)
			}
		}

		// Verify count + sum-of-amount round-trip.
		var (
			cnt    int
			sumAmt int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*), COALESCE(SUM(amount), 0) FROM user_bingo WHERE guid = $1`,
			cidBingoA).Scan(&cnt, &sumAmt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 4 || sumAmt != 16 {
			t.Fatalf("4 rows: got cnt=%d sum=%d, want 4/16", cnt, sumAmt)
		}
	})

	t.Run("duplicate put ALSO inserts (no UNIQUE — append-only audit)", func(t *testing.T) {
		// Same all-args 3 times under cidBingoB — must produce 3 rows.
		base := struct {
			btype  int16
			nameid int32
			status int16
			amt    int16
		}{1, 9999, 0, 2}

		for i := 0; i < 3; i++ {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putbingocoin",
				cidBingoB, base.btype, base.nameid, base.status, int32(bingoAccountB), base.amt,
			).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow #%d: %v", i+1, err)
			}
			if affected != 1 {
				t.Fatalf("dup #%d: got %d, want 1", i+1, affected)
			}
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_bingo
			  WHERE guid = $1 AND bingo_type = $2 AND bingo_nameid = $3`,
			cidBingoB, base.btype, base.nameid).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 3 {
			t.Fatalf("dup rows: got %d, want 3 (no UNIQUE constraint)", cnt)
		}
	})

	t.Run("neighbour isolation: B's puts don't pollute A", func(t *testing.T) {
		// Verify A still holds exactly 4 rows (from the prior subtest), not
		// 4 + 3 from B's contribution.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_bingo WHERE guid = $1`,
			cidBingoA).Scan(&cnt); err != nil {
			t.Fatalf("count A: %v", err)
		}
		if cnt != 4 {
			t.Fatalf("A leaked from B: got %d rows, want 4", cnt)
		}
	})

	t.Run("audit row survives parent char deletion (no FK)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putbingocoin",
			cidBingoOrphan, int16(1), int32(7777), int16(0), int32(bingoAccountA), int16(9),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow orphan: %v", err)
		}
		if affected != 1 {
			t.Fatalf("orphan put: got %d, want 1", affected)
		}

		// Hard-delete the parent — emotion test pattern proved this is safe.
		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM user_data WHERE char_id = $1`, cidBingoOrphan); err != nil {
			t.Fatalf("delete user_data: %v", err)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_bingo WHERE guid = $1`,
			cidBingoOrphan).Scan(&cnt); err != nil {
			t.Fatalf("count orphan: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("orphan audit vanished: got %d, want 1", cnt)
		}
	})
}
