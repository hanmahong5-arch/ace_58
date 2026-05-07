// Package database — integration test for aion_SetGuildJoinRestrictLevel.
//
// One-column UPDATE on guild.join_restrict_level. Bug-for-bug NCSoft: no
// existence guard.
//
// Test matrix:
//   - happy path: existing guild → 1 row, value persisted
//   - boundary values 0 / 1 / 65 (5.8 lvl cap) round-trip
//   - missing guild → 0 rows (silent no-op)
//   - neighbour isolation: A's set doesn't perturb B
package database

import (
	"context"
	"testing"
	"time"
)

const (
	gidJoinRLvlA       = 9460001
	gidJoinRLvlB       = 9460002
	gidJoinRLvlMissing = 9460099
)

func setGuildJoinRestrictLevelCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM guild WHERE id BETWEEN 9460001 AND 9460099`); err != nil {
		t.Fatalf("setGuildJoinRestrictLevelCleanup guild: %v", err)
	}
}

func TestSetGuildJoinRestrictLevel(t *testing.T) {
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

	setGuildJoinRestrictLevelCleanup(t, ctx, pool)
	t.Cleanup(func() { setGuildJoinRestrictLevelCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{gidJoinRLvlA, "JoinRLvlA"},
		{gidJoinRLvlB, "JoinRLvlB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name) VALUES ($1, $2)`,
			seed.id, seed.name); err != nil {
			t.Fatalf("seed guild %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: 1 row updated, value persisted", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildjoinrestrictlevel",
			gidJoinRLvlA, int16(50)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var got int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT join_restrict_level FROM guild WHERE id = $1`,
			gidJoinRLvlA).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != 50 {
			t.Fatalf("join_restrict_level: got %d, want 50", got)
		}
	})

	t.Run("boundary values 0 / 1 / 65 round-trip", func(t *testing.T) {
		// 0 = no restriction; 65 = 5.8 char level cap.
		for _, want := range []int16{0, 1, 65} {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_setguildjoinrestrictlevel",
				gidJoinRLvlA, want).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow %d: %v", want, err)
			}
			if affected != 1 {
				t.Fatalf("set %d: got %d, want 1", want, affected)
			}

			var got int
			if err := pool.Inner().QueryRow(ctx,
				`SELECT join_restrict_level FROM guild WHERE id = $1`,
				gidJoinRLvlA).Scan(&got); err != nil {
				t.Fatalf("verify %d: %v", want, err)
			}
			if int16(got) != want {
				t.Fatalf("round-trip %d: got %d", want, got)
			}
		}
	})

	t.Run("missing guild → 0 rows (silent no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildjoinrestrictlevel",
			gidJoinRLvlMissing, int16(10)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing: got %d, want 0", affected)
		}
	})

	t.Run("neighbour isolation: A's set doesn't perturb B", func(t *testing.T) {
		var beforeB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT join_restrict_level FROM guild WHERE id = $1`,
			gidJoinRLvlB).Scan(&beforeB); err != nil {
			t.Fatalf("read B before: %v", err)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildjoinrestrictlevel",
			gidJoinRLvlA, int16(40)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if affected != 1 {
			t.Fatalf("A: got %d, want 1", affected)
		}

		var afterB int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT join_restrict_level FROM guild WHERE id = $1`,
			gidJoinRLvlB).Scan(&afterB); err != nil {
			t.Fatalf("read B after: %v", err)
		}
		if afterB != beforeB {
			t.Fatalf("B drift: %d → %d (A leak)", beforeB, afterB)
		}
	})
}
