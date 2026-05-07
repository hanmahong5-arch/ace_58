// Package database — integration test for aion_GetClientQuickBarList.
//
// Returns (data_size, data) for the given char_id, or 0 rows when the char
// has never pushed a quickbar blob. Mirrors the user_client_settings (00154)
// contract: opaque BYTEA round-trip must be byte-perfect; data_size scans
// as int16 (PG SMALLINT).
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidQbA = 9001940 // owner with a quickbar blob
	cidQbB = 9001941 // owner with NO blob (control)
)

func clientQuickbarListGetCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_quickbar WHERE char_id BETWEEN 9001940 AND 9001999`); err != nil {
		t.Fatalf("clientQuickbarListGetCleanup uq: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001940 AND 9001999`); err != nil {
		t.Fatalf("clientQuickbarListGetCleanup user_data: %v", err)
	}
}

func TestGetClientQuickBarList(t *testing.T) {
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

	clientQuickbarListGetCleanup(t, ctx, pool)
	t.Cleanup(func() { clientQuickbarListGetCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidQbA, "QbA"},
		{cidQbB, "QbB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "qb_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Seed a non-trivial blob (8 bytes — distinct sentinel so any silent
	// zero-fill or truncation bug is detectable).
	wantBlob := []byte{0xCA, 0xFE, 0xBA, 0xBE, 0xDE, 0xAD, 0xBE, 0xEF}
	wantSize := int16(len(wantBlob))
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_client_quickbar(char_id, data_size, data) VALUES ($1, $2, $3)`,
		cidQbA, wantSize, wantBlob); err != nil {
		t.Fatalf("seed blob: %v", err)
	}

	t.Run("char with quickbar returns one row, byte-perfect", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getclientquickbarlist", cidQbA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		var (
			gotSize int16
			gotData []byte
			n       int
		)
		for rs.Next() {
			n++
			if err := rs.Scan(&gotSize, &gotData); err != nil {
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

	t.Run("char without quickbar returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getclientquickbarlist", cidQbB)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var n int
		for rs.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing-blob char: got %d rows, want 0", n)
		}
	})
}
