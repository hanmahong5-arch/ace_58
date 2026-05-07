// Package database — integration test for aion_GetItemCoolTime.
//
// Returns (cooltime_data_cnt, data) for char's packed item-cooltime blob.
// One-row blob (PK char_id) — same single-row contract as quickbar/favorite.
//
// Test matrix:
//   - char with blob → 1 row, byte-perfect round-trip
//   - char without blob → 0 rows
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidIctA = 9001920 // owner with item-cooltime blob
	cidIctB = 9001921 // owner with NO blob
)

func getItemCoolTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_cooltime WHERE char_id BETWEEN 9001920 AND 9001929`); err != nil {
		t.Fatalf("getItemCoolTimeCleanup user_item_cooltime: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001920 AND 9001929`); err != nil {
		t.Fatalf("getItemCoolTimeCleanup user_data: %v", err)
	}
}

func TestGetItemCoolTime(t *testing.T) {
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

	getItemCoolTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { getItemCoolTimeCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidIctA, "IctA"},
		{cidIctB, "IctB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "ic_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// Sentinel blob — magic "ICT*" + tail bytes; cnt=2 represents two packed (item_id, expire_ms) tuples.
	wantBlob := []byte{0x49, 0x43, 0x54, 0x2A, 0xCA, 0xFE, 0xBA, 0xBE}
	wantCnt := int16(2)
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_item_cooltime(char_id, cooltime_data_cnt, data) VALUES ($1, $2, $3)`,
		cidIctA, wantCnt, wantBlob); err != nil {
		t.Fatalf("seed blob: %v", err)
	}

	t.Run("char with blob returns one row, byte-perfect", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getitemcooltime", cidIctA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		var (
			gotCnt  int16
			gotData []byte
			n       int
		)
		for rs.Next() {
			n++
			if err := rs.Scan(&gotCnt, &gotData); err != nil {
				t.Fatalf("Scan: %v", err)
			}
		}
		if n != 1 {
			t.Fatalf("row count: got %d, want 1", n)
		}
		if gotCnt != wantCnt {
			t.Fatalf("cooltime_data_cnt: got %d, want %d", gotCnt, wantCnt)
		}
		if !bytes.Equal(gotData, wantBlob) {
			t.Fatalf("data round-trip: got %x, want %x", gotData, wantBlob)
		}
	})

	t.Run("char without blob returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getitemcooltime", cidIctB)
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
