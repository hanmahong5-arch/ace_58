// Package database — integration test for aion_SetGuildJoinProcessType.
//
// One-column UPDATE on guild.join_process_type. Bug-for-bug NCSoft: no
// existence guard.
//
// Test matrix:
//   - happy path: existing guild → 1 row, value persisted
//   - all enum values 0..2 round-trip through the SP
//   - missing guild → 0 rows (silent no-op)
//   - neighbour isolation: A's set doesn't perturb B
package database

import (
	"context"
	"testing"
	"time"
)

const (
	gidJoinPTypeA       = 9450001
	gidJoinPTypeB       = 9450002
	gidJoinPTypeMissing = 9450099
)

func setGuildJoinProcessTypeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM guild WHERE id BETWEEN 9450001 AND 9450099`); err != nil {
		t.Fatalf("setGuildJoinProcessTypeCleanup guild: %v", err)
	}
}

func TestSetGuildJoinProcessType(t *testing.T) {
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

	setGuildJoinProcessTypeCleanup(t, ctx, pool)
	t.Cleanup(func() { setGuildJoinProcessTypeCleanup(t, context.Background(), pool) })

	// Seed 2 sentinel legions (default join_process_type = 0 from 00002).
	for _, seed := range []struct {
		id   int
		name string
	}{
		{gidJoinPTypeA, "JoinPTypeA"},
		{gidJoinPTypeB, "JoinPTypeB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name) VALUES ($1, $2)`,
			seed.id, seed.name); err != nil {
			t.Fatalf("seed guild %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: 1 row updated, value persisted", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildjoinprocesstype",
			gidJoinPTypeA, int16(2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var got int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT join_process_type FROM guild WHERE id = $1`,
			gidJoinPTypeA).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 2 {
			t.Fatalf("join_process_type: got %d, want 2", got)
		}
	})

	t.Run("enum 0..2 round-trip", func(t *testing.T) {
		// 0 = closed, 1 = auto-approve, 2 = require-approval.
		for _, want := range []int16{0, 1, 2} {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_setguildjoinprocesstype",
				gidJoinPTypeA, want).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow %d: %v", want, err)
			}
			if affected != 1 {
				t.Fatalf("set %d: got %d, want 1", want, affected)
			}

			var got int
			if err := pool.Inner().QueryRow(ctx,
				`SELECT join_process_type FROM guild WHERE id = $1`,
				gidJoinPTypeA).Scan(&got); err != nil {
				t.Fatalf("verify %d: %v", want, err)
			}
			if int16(got) != want {
				t.Fatalf("round-trip %d: got %d", want, got)
			}
		}
	})

	t.Run("missing guild → 0 rows (silent no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildjoinprocesstype",
			gidJoinPTypeMissing, int16(1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing: got %d, want 0", affected)
		}
	})

	t.Run("neighbour isolation: A's set doesn't perturb B", func(t *testing.T) {
		// Snapshot B before, perturb A, re-read B.
		var beforeB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT join_process_type FROM guild WHERE id = $1`,
			gidJoinPTypeB).Scan(&beforeB); err != nil {
			t.Fatalf("read B before: %v", err)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildjoinprocesstype",
			gidJoinPTypeA, int16(2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if affected != 1 {
			t.Fatalf("A: got %d, want 1", affected)
		}

		var afterB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT join_process_type FROM guild WHERE id = $1`,
			gidJoinPTypeB).Scan(&afterB); err != nil {
			t.Fatalf("read B after: %v", err)
		}
		if afterB != beforeB {
			t.Fatalf("B drift: %d → %d (A leak)", beforeB, afterB)
		}
	})
}
