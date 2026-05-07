// Package database — integration test for aion_SetTownData (server-wide town UPSERT).
//
// UPSERT (town_id PK) on town_data with (point, "lastLvChangedTime"). Both
// branches return rows-affected = 1 (mirrors NCSoft @@ROWCOUNT for the
// IF EXISTS / ELSE branches collapsed into a single ON CONFLICT statement).
//
// town_data is server-wide singleton-per-town — there is NO char_id
// involvement. We pick a town_id band well above any real catalog id to
// avoid collision with seeded gameplay data.
//
// Test matrix:
//   - first call inserts: 1 row affected, both columns round-trip
//   - second call same town updates: still 1 row affected, payload changes
//   - distinct town_ids coexist independently
//   - negative point accepted (GM-rollback pin)
//   - quoted column "lastLvChangedTime" preserved (case-sensitive read works)
//
// town_id band: 990001..990099 (server-state side; far outside the
// typical 1..1000 catalog range).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	townSetA   = 990001
	townSetB   = 990002
	townSetNeg = 990003
	townSetCS  = 990004 // case-sensitive column read
)

func setTownDataCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM town_data WHERE town_id BETWEEN 990001 AND 990099`); err != nil {
		t.Fatalf("setTownDataCleanup town_data: %v", err)
	}
}

func TestSetTownData(t *testing.T) {
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

	setTownDataCleanup(t, ctx, pool)
	t.Cleanup(func() { setTownDataCleanup(t, context.Background(), pool) })

	t.Run("first call inserts, full payload round-trip", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settowndata",
			townSetA, int(12500), int(1700001000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var (
			pt      int
			lastLv  int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT point, "lastLvChangedTime" FROM town_data WHERE town_id=$1`,
			townSetA).Scan(&pt, &lastLv); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if pt != 12500 || lastLv != 1700001000 {
			t.Fatalf("payload: point=%d lastLv=%d, want 12500/1700001000",
				pt, lastLv)
		}
	})

	t.Run("second call same town updates both columns, row count stays 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settowndata",
			townSetA, int(15000), int(1700099000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow update: %v", err)
		}
		if affected != 1 {
			// NCSoft @@ROWCOUNT semantics: update branch returns 1.
			t.Fatalf("update: got affected=%d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM town_data WHERE town_id=$1`,
			townSetA).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("after update: got %d rows, want 1", n)
		}

		var (
			pt     int
			lastLv int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT point, "lastLvChangedTime" FROM town_data WHERE town_id=$1`,
			townSetA).Scan(&pt, &lastLv); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if pt != 15000 || lastLv != 1700099000 {
			t.Fatalf("updated payload: point=%d lastLv=%d, want 15000/1700099000",
				pt, lastLv)
		}
	})

	t.Run("distinct town_ids coexist", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settowndata",
			townSetB, int(7000), int(1700002000)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B insert affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM town_data WHERE town_id IN ($1, $2)`,
			townSetA, townSetB).Scan(&n); err != nil {
			t.Fatalf("count two towns: %v", err)
		}
		if n != 2 {
			t.Fatalf("two towns: got %d rows, want 2", n)
		}

		// And the A row's value MUST still be the previously updated 15000.
		var ptA int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT point FROM town_data WHERE town_id=$1`, townSetA).
			Scan(&ptA); err != nil {
			t.Fatalf("verify A isolation: %v", err)
		}
		if ptA != 15000 {
			t.Fatalf("isolation: town A point got %d, want 15000", ptA)
		}
	})

	t.Run("negative point accepted (GM-rollback pin)", func(t *testing.T) {
		// Pin: NCSoft has no CHECK on point; GM tools occasionally write
		// negative point for rollback corrections. Pinned verbatim.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settowndata",
			townSetNeg, int(-500), int(0)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow neg: %v", err)
		}
		if affected != 1 {
			t.Fatalf("neg affected: got %d, want 1", affected)
		}

		var pt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT point FROM town_data WHERE town_id=$1`,
			townSetNeg).Scan(&pt); err != nil {
			t.Fatalf("verify neg: %v", err)
		}
		if pt != -500 {
			t.Fatalf("neg round-trip: got %d, want -500", pt)
		}
	})

	t.Run("quoted lastLvChangedTime column preserves case", func(t *testing.T) {
		// The column is camelCase (NCSoft pin). PG would have folded it to
		// lastlvchangedtime without the double-quotes. Verify we can read
		// it via the EXACT case used in the SP.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settowndata",
			townSetCS, int(42), int(1700123456)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow CS: %v", err)
		}
		if affected != 1 {
			t.Fatalf("CS affected: got %d, want 1", affected)
		}

		// Use the quoted identifier — this is the canary for case preservation.
		var lastLv int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT "lastLvChangedTime" FROM town_data WHERE town_id=$1`,
			townSetCS).Scan(&lastLv); err != nil {
			t.Fatalf("verify CS: %v", err)
		}
		if lastLv != 1700123456 {
			t.Fatalf("CS round-trip: got %d, want 1700123456", lastLv)
		}
	})
}
