// Package database — integration test for aion_ClientSettingsListGet.
//
// Returns (data_size, data) for the given char_id, or 0 rows when the char
// has never pushed a client-settings blob. Pairs with aion_ClientSettingsPut
// (00155) which is the only producer of the rows we read back here. The blob
// is opaque server-side; the test verifies byte-perfect round-trip and that
// missing-row + present-row both return the right shape.
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidCsListA = 9001540 // owner with a settings blob
	cidCsListB = 9001541 // owner with NO blob (control)
)

func clientSettingsListGetCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_settings WHERE char_id BETWEEN 9001540 AND 9001599`); err != nil {
		t.Fatalf("clientSettingsListGetCleanup ucs: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001540 AND 9001599`); err != nil {
		t.Fatalf("clientSettingsListGetCleanup user_data: %v", err)
	}
}

func TestClientSettingsListGet(t *testing.T) {
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

	clientSettingsListGetCleanup(t, ctx, pool)
	t.Cleanup(func() { clientSettingsListGetCleanup(t, context.Background(), pool) })

	// Seed user_data so FK-style invariants in adjacent SPs stay satisfied
	// (the SP itself doesn't FK into user_data, but cm_* handlers do).
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidCsListA, "CsListA"},
		{cidCsListB, "CsListB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "cs_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Seed a non-trivial blob (4 bytes, distinct from defaults so any
	// silent zero-fill bug is detectable).
	wantBlob := []byte{0xDE, 0xAD, 0xBE, 0xEF}
	wantSize := int16(len(wantBlob))
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_client_settings(char_id, data_size, data) VALUES ($1, $2, $3)`,
		cidCsListA, wantSize, wantBlob); err != nil {
		t.Fatalf("seed blob: %v", err)
	}

	t.Run("char with blob returns one row, byte-perfect", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_clientsettingslistget", cidCsListA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		var (
			gotSize int16
			gotData []byte
			n       int
		)
		for rows.Next() {
			n++
			if err := rows.Scan(&gotSize, &gotData); err != nil {
				t.Fatalf("Scan: %v", err)
			}
		}
		if n != 1 {
			t.Fatalf("row count: got %d, want 1", n)
		}
		if gotSize != wantSize {
			t.Fatalf("data_size: got %d, want %d", gotSize, wantSize)
		}
		if !bytes.Equal(gotData, wantBlob) {
			t.Fatalf("data round-trip: got %x, want %x", gotData, wantBlob)
		}
	})

	t.Run("char without blob returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_clientsettingslistget", cidCsListB)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing-blob char: got %d rows, want 0", n)
		}
	})
}
