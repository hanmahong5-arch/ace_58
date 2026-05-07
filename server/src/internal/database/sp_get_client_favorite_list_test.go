// Package database — integration test for aion_GetClientFavoriteList.
//
// Returns (data_size, data) for the given char_id, or 0 rows when the char
// has never pushed a favorites blob. Mirrors the quickbar (00160) contract.
//
// Note: NCSoft case-mixed table name `user_client_Favorite` becomes plain
// `user_client_favorite` in PG (PG folds unquoted identifiers to lowercase).
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidFavA = 9001950 // owner with a favorites blob
	cidFavB = 9001951 // owner with NO blob (control)
)

func clientFavoriteListGetCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_favorite WHERE char_id BETWEEN 9001950 AND 9001999`); err != nil {
		t.Fatalf("clientFavoriteListGetCleanup uf: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001950 AND 9001999`); err != nil {
		t.Fatalf("clientFavoriteListGetCleanup user_data: %v", err)
	}
}

func TestGetClientFavoriteList(t *testing.T) {
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

	clientFavoriteListGetCleanup(t, ctx, pool)
	t.Cleanup(func() { clientFavoriteListGetCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidFavA, "FavA"},
		{cidFavB, "FavB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "fv_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Sentinel blob — 6 bytes spelling "FAV*" + tail bytes.
	wantBlob := []byte{0x46, 0x41, 0x56, 0x2A, 0xFE, 0xED}
	wantSize := int16(len(wantBlob))
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_client_favorite(char_id, data_size, data) VALUES ($1, $2, $3)`,
		cidFavA, wantSize, wantBlob); err != nil {
		t.Fatalf("seed blob: %v", err)
	}

	t.Run("char with favorites returns one row, byte-perfect", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getclientfavoritelist", cidFavA)
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

	t.Run("char without favorites returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getclientfavoritelist", cidFavB)
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
