// Package database — integration test for aion_GetPetitionWebNotify.
//
// Per-character web-petition opt-in lookup. Returns 1 row (char_id echo)
// when the user has opted in, 0 rows otherwise — mere row existence is
// the signal, not the value.
//
// Test matrix:
//   - opted-in char  → 1 row, returned char_id == input
//   - never-opted-in → 0 rows
//   - other char's opt-in does NOT leak to the queried char (isolation)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidPetWebOptIn  = 9001950 // opted-in char
	cidPetWebOptOut = 9001951 // never opted in
	cidPetWebOther  = 9001952 // a third char, used for isolation
)

func getPetitionWebNotifyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_petition_web WHERE char_id BETWEEN 9001950 AND 9001959`); err != nil {
		t.Fatalf("getPetitionWebNotifyCleanup user_petition_web: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001950 AND 9001959`); err != nil {
		t.Fatalf("getPetitionWebNotifyCleanup user_data: %v", err)
	}
}

func TestGetPetitionWebNotify(t *testing.T) {
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

	getPetitionWebNotifyCleanup(t, ctx, pool)
	t.Cleanup(func() { getPetitionWebNotifyCleanup(t, context.Background(), pool) })

	// Seed user_data for FK-style sanity (user_petition_web has no FK but the
	// matching cleanup pattern across all SPs assumes user_data parents exist).
	for _, cid := range []int{cidPetWebOptIn, cidPetWebOptOut, cidPetWebOther} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'pw_'||$1::TEXT, 'pwu_'||$1::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	// Two chars opt in; a third never does.
	for _, cid := range []int{cidPetWebOptIn, cidPetWebOther} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_petition_web(char_id) VALUES ($1)`, cid); err != nil {
			t.Fatalf("seed petition_web %d: %v", cid, err)
		}
	}

	t.Run("opted-in char returns 1 row with echoed char_id", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionwebnotify", cidPetWebOptIn)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n      int
			gotCID int
		)
		for rows.Next() {
			if err := rows.Scan(&gotCID); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || gotCID != cidPetWebOptIn {
			t.Fatalf("opted-in: n=%d cid=%d, want n=1 cid=%d", n, gotCID, cidPetWebOptIn)
		}
	})

	t.Run("never-opted-in char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionwebnotify", cidPetWebOptOut)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("opted-out: got %d rows, want 0", n)
		}
	})

	t.Run("isolation: querying one char does not surface another's opt-in", func(t *testing.T) {
		// cidPetWebOther is opted in too; verify the SP filter is per-char.
		rows, err := pool.CallSP(ctx, "aion_getpetitionwebnotify", cidPetWebOptOut)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("isolation: opted-out char saw %d rows (other chars leaked), want 0", n)
		}
	})
}
