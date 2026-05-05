// Package database — integration test for aion_GetCharIdByName.
//
// PG-only SP (no NCSoft equivalent). Used by scripts/lib/mail.lua to resolve
// the recipient_name on player→player mail before InsertMailUser. Other Lua
// callers (friend / whisper / guild invite) are deferred until those features
// land.
//
// Convention follows sp_pve_round*_test.go: env-gated via testDSN(), Skip()
// on missing PG, dedicated cleanup band so the test is independent.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidNameLive    = 9000800
	cidNameDeleted = 9000801
)

func charIDByNameCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9000800 AND 9000899`); err != nil {
		t.Fatalf("charIDByNameCleanup: %v", err)
	}
}

func TestGetCharIdByName(t *testing.T) {
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

	charIDByNameCleanup(t, ctx, pool)
	t.Cleanup(func() { charIDByNameCleanup(t, context.Background(), pool) })

	// Seed: live char + soft-deleted char (same name space, distinct names).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'AliceLive', 'cidn_live')`,
		cidNameLive); err != nil {
		t.Fatalf("seed live: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, delete_date)
		 VALUES ($1, 'BobGhost', 'cidn_ghost', 1700000000)`,
		cidNameDeleted); err != nil {
		t.Fatalf("seed ghost: %v", err)
	}

	t.Run("live char resolves", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getcharidbyname", "AliceLive")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var got, n int
		for rows.Next() {
			if err := rows.Scan(&got); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || got != cidNameLive {
			t.Fatalf("live: n=%d got=%d, want n=1 got=%d", n, got, cidNameLive)
		}
	})

	t.Run("unknown name returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getcharidbyname", "NoSuchPlayer")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("unknown: got %d rows, want 0", n)
		}
	})

	t.Run("soft-deleted char hidden", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getcharidbyname", "BobGhost")
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

	t.Run("name lookup is case-sensitive", func(t *testing.T) {
		// PG default is C-collation case-sensitive equality. AION names are
		// case-insensitive on the wire but the runtime stores them with the
		// caller-chosen case; an exact-match lookup avoids surprises like
		// "alice" matching "Alice" but not "AliceLive". This test pins the
		// behavior so a future LOWER() optimization is an explicit decision.
		rows, err := pool.CallSP(ctx, "aion_getcharidbyname", "alicelive")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("lowercase lookup: got %d rows, want 0 (case-sensitive)", n)
		}
	})
}
