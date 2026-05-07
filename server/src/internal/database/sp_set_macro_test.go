// Package database — integration test for aion_SetMacro (upsert).
//
// Atomic INSERT-or-UPDATE on user_macro keyed by (char_id, slot_id).
// Test matrix:
//   - first call inserts, returns 1 affected row, blob persists byte-perfect
//   - second call on same (char_id, slot_id) updates in place (still 1 row),
//     replaces the blob, no duplicate row appears
//   - second slot on same char inserts as a new row (does NOT collide)
//   - 1024-byte blob (NCSoft NVARCHAR(1024) cap upper bound) round-trips
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidMacroSetA = 9001942 // upsert target
	cidMacroSetB = 9001943 // separate char to confirm row isolation
)

func setMacroCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_macro WHERE char_id BETWEEN 9001942 AND 9001949`); err != nil {
		t.Fatalf("setMacroCleanup user_macro: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001942 AND 9001949`); err != nil {
		t.Fatalf("setMacroCleanup user_data: %v", err)
	}
}

func TestSetMacro(t *testing.T) {
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

	setMacroCleanup(t, ctx, pool)
	t.Cleanup(func() { setMacroCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidMacroSetA, "MacSetA"},
		{cidMacroSetB, "MacSetB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "ms_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("first set inserts new slot", func(t *testing.T) {
		blob := []byte{0x10, 0x20, 0x30}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setmacro",
			cidMacroSetA, int16(0), blob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first set: got %d, want 1", affected)
		}

		var gotData []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_macro WHERE char_id = $1 AND slot_id = $2`,
			cidMacroSetA, 0).Scan(&gotData); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if !bytes.Equal(gotData, blob) {
			t.Fatalf("inserted blob mismatch: got %x, want %x", gotData, blob)
		}
	})

	t.Run("second set on same slot updates in place (no duplicate)", func(t *testing.T) {
		newBlob := []byte{0xAA, 0xBB, 0xCC, 0xDD, 0xEE}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setmacro",
			cidMacroSetA, int16(0), newBlob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("update set: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_macro WHERE char_id = $1 AND slot_id = $2`,
			cidMacroSetA, 0).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after update: got %d, want 1 (no duplicate)", rowCnt)
		}

		var gotData []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_macro WHERE char_id = $1 AND slot_id = $2`,
			cidMacroSetA, 0).Scan(&gotData); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if !bytes.Equal(gotData, newBlob) {
			t.Fatalf("updated blob mismatch: got %x, want %x", gotData, newBlob)
		}
	})

	t.Run("different slot on same char inserts new row", func(t *testing.T) {
		blob := []byte{0xF0, 0x0D}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setmacro",
			cidMacroSetA, int16(5), blob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("new slot: got %d, want 1", affected)
		}

		// Char A now owns 2 distinct slots (0 and 5).
		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_macro WHERE char_id = $1`,
			cidMacroSetA).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 2 {
			t.Fatalf("rows for char A: got %d, want 2 (slots 0 + 5)", rowCnt)
		}
	})

	t.Run("max-size 1024 byte blob round-trips", func(t *testing.T) {
		// NCSoft NVARCHAR(1024) cap (interpreted as UTF-16 code units = 2048
		// bytes max in T-SQL, but our BYTEA path stores raw bytes; use 1024
		// as a conservative upper bound that any caller would actually send).
		bigBlob := make([]byte, 1024)
		for i := range bigBlob {
			bigBlob[i] = byte(i & 0xFF)
		}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setmacro",
			cidMacroSetB, int16(7), bigBlob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow big: %v", err)
		}
		if affected != 1 {
			t.Fatalf("big set: got %d, want 1", affected)
		}

		var gotData []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_macro WHERE char_id = $1 AND slot_id = $2`,
			cidMacroSetB, 7).Scan(&gotData); err != nil {
			t.Fatalf("verify big: %v", err)
		}
		if !bytes.Equal(gotData, bigBlob) {
			t.Fatalf("1024-byte round-trip failed (len got=%d, want=%d)",
				len(gotData), len(bigBlob))
		}
	})
}
