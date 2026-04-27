// Package database — integration test for aion_GetAbyssPointUser.
//
// PG-only SP. Used by scripts/handlers/cm_enter_world.lua to hydrate the
// abyss_point stat when the GetCharInfo row didn't carry it. Returns a
// single BIGINT column; 0 rows when the char is missing or soft-deleted.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidApFresh   = 9000900 // freshly created, AP defaults to 0
	cidApLoaded  = 9000901 // hand-set abyss_point
	cidApDeleted = 9000902 // soft-deleted
	cidApMissing = 9000999 // never inserted
)

func abyssPointCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9000900 AND 9000999`); err != nil {
		t.Fatalf("abyssPointCleanup: %v", err)
	}
}

func TestGetAbyssPointUser(t *testing.T) {
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

	abyssPointCleanup(t, ctx, pool)
	t.Cleanup(func() { abyssPointCleanup(t, context.Background(), pool) })

	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'ApFresh', 'ap_fresh')`,
		cidApFresh); err != nil {
		t.Fatalf("seed fresh: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, abyss_point)
		 VALUES ($1, 'ApLoaded', 'ap_loaded', 1234567890123)`,
		cidApLoaded); err != nil {
		t.Fatalf("seed loaded: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, abyss_point, delete_date)
		 VALUES ($1, 'ApGhost', 'ap_ghost', 999999, 1700000000)`,
		cidApDeleted); err != nil {
		t.Fatalf("seed ghost: %v", err)
	}

	t.Run("fresh char returns 0", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getabysspointuser", cidApFresh)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var got int64
		var n int
		for rows.Next() {
			if err := rows.Scan(&got); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || got != 0 {
			t.Fatalf("fresh: n=%d got=%d, want n=1 got=0", n, got)
		}
	})

	t.Run("loaded char returns BIGINT value", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getabysspointuser", cidApLoaded)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var got int64
		var n int
		for rows.Next() {
			if err := rows.Scan(&got); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		const want int64 = 1234567890123
		if n != 1 || got != want {
			t.Fatalf("loaded: n=%d got=%d, want n=1 got=%d", n, got, want)
		}
	})

	t.Run("missing char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getabysspointuser", cidApMissing)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing: got %d rows, want 0", n)
		}
	})

	t.Run("soft-deleted char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getabysspointuser", cidApDeleted)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("soft-deleted: got %d rows, want 0 (delete_date filter)", n)
		}
	})
}
