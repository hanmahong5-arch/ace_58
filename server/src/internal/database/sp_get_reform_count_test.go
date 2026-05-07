// Package database — integration test for aion_GetReformCount.
//
// SELECT (next_reset_time, reform_count) for a given char from user_reform.
// Sister of 00218 SetReformCount.
//
// Test matrix:
//   - char never reformed returns 0 rows (no implicit zero row)
//   - first Set then Get reads back the exact payload
//   - update via Set replaces both columns; Get reads new values
//   - neighbour isolation: other char's row does not appear
//
// char_id band: 9_540_020..9_540_029 (R16 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidReformGetEmpty = 9540020 // seeded user_data, no reform row
	cidReformGetOne   = 9540021 // single Set then Get
	cidReformGetMod   = 9540022 // Set then Set-again then Get
	cidReformGetOther = 9540023 // neighbour for isolation
)

func getReformCountCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_reform WHERE char_id BETWEEN 9540020 AND 9540029`); err != nil {
		t.Fatalf("getReformCountCleanup user_reform: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9540020 AND 9540029`); err != nil {
		t.Fatalf("getReformCountCleanup user_data: %v", err)
	}
}

func TestGetReformCount(t *testing.T) {
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

	getReformCountCleanup(t, ctx, pool)
	t.Cleanup(func() { getReformCountCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidReformGetEmpty, "RfGetEmpty"},
		{cidReformGetOne, "RfGetOne"},
		{cidReformGetMod, "RfGetMod"},
		{cidReformGetOther, "RfGetOther"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "rfg_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Use SetReformCount as the production data path for seeding.
	if err := pool.CallSPExec(ctx, "aion_setreformcount",
		cidReformGetOne, int(1700000100), int(3)); err != nil {
		t.Fatalf("seed One: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_setreformcount",
		cidReformGetMod, int(1700000200), int(5)); err != nil {
		t.Fatalf("seed Mod (initial): %v", err)
	}
	// Update Mod a second time — verifies Get reads the latest payload.
	if err := pool.CallSPExec(ctx, "aion_setreformcount",
		cidReformGetMod, int(1700099999), int(99)); err != nil {
		t.Fatalf("seed Mod (update): %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_setreformcount",
		cidReformGetOther, int(1700000300), int(1)); err != nil {
		t.Fatalf("seed Other: %v", err)
	}

	t.Run("char never reformed returns 0 rows", func(t *testing.T) {
		// Empty user has no row in user_reform — Get must return 0 rows,
		// NOT an implicit "0 count, 0 reset_time" row. Lua callers rely on
		// this absence to distinguish "first reform of cycle" vs "n-th".
		rows, err := pool.CallSP(ctx, "aion_getreformcount", cidReformGetEmpty)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var cnt int
		for rows.Next() {
			cnt++
		}
		if cnt != 0 {
			t.Fatalf("never-reformed: got %d rows, want 0 (no implicit zero row)", cnt)
		}
	})

	t.Run("single Set round-trips both columns", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getreformcount", cidReformGetOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			nextReset, count int
			n                int
		)
		for rows.Next() {
			if err := rows.Scan(&nextReset, &count); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("single: got %d rows, want 1", n)
		}
		if nextReset != 1700000100 || count != 3 {
			t.Fatalf("single payload: reset=%d count=%d, want 1700000100/3",
				nextReset, count)
		}
	})

	t.Run("update via Set replaces both columns", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getreformcount", cidReformGetMod)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			nextReset, count int
			n                int
		)
		for rows.Next() {
			if err := rows.Scan(&nextReset, &count); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("modified: got %d rows, want 1 (UPSERT must not duplicate)", n)
		}
		// Latest write wins: 1700099999/99, not the earlier 1700000200/5.
		if nextReset != 1700099999 || count != 99 {
			t.Fatalf("modified payload: reset=%d count=%d, want 1700099999/99",
				nextReset, count)
		}
	})

	t.Run("neighbour isolation: other char's payload does not appear", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getreformcount", cidReformGetOne)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var leaked bool
		for rows.Next() {
			var nextReset, count int
			if err := rows.Scan(&nextReset, &count); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			// cidReformGetOther's payload (1700000300/1) must NOT show up here.
			if nextReset == 1700000300 || count == 1 && nextReset != 1700000100 {
				leaked = true
			}
		}
		if leaked {
			t.Fatalf("isolation: cidReformGetOther payload leaked into cidReformGetOne result")
		}
	})
}
