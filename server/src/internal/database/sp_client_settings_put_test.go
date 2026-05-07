// Package database — integration test for aion_ClientSettingsPut (upsert).
//
// Atomic INSERT-or-UPDATE on user_client_settings keyed by char_id.
// Test matrix:
//   - first call inserts, returns 1 affected row, blob persists byte-perfect
//   - second call on same char_id updates in place (still 1 row affected),
//     replaces the blob, no duplicate row appears
//   - large blob (7168 bytes — original NCSoft varbinary cap) round-trips
//     without truncation
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidCsPutA = 9001550 // upsert target
	cidCsPutB = 9001551 // separate char to confirm row isolation
)

func clientSettingsPutCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_settings WHERE char_id BETWEEN 9001550 AND 9001599`); err != nil {
		t.Fatalf("clientSettingsPutCleanup ucs: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001550 AND 9001599`); err != nil {
		t.Fatalf("clientSettingsPutCleanup user_data: %v", err)
	}
}

func TestClientSettingsPut(t *testing.T) {
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

	clientSettingsPutCleanup(t, ctx, pool)
	t.Cleanup(func() { clientSettingsPutCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidCsPutA, "CsPutA"},
		{cidCsPutB, "CsPutB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "csp_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	t.Run("first put inserts new row", func(t *testing.T) {
		blob := []byte{0x01, 0x02, 0x03}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clientsettingsput",
			cidCsPutA, int16(len(blob)), blob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first put: got %d, want 1", affected)
		}

		var (
			gotSize int16
			gotData []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data_size, data FROM user_client_settings WHERE char_id = $1`,
			cidCsPutA).Scan(&gotSize, &gotData); err != nil {
			t.Fatalf("verify row: %v", err)
		}
		if gotSize != int16(len(blob)) || !bytes.Equal(gotData, blob) {
			t.Fatalf("inserted blob mismatch: size=%d data=%x, want size=%d data=%x",
				gotSize, gotData, len(blob), blob)
		}
	})

	t.Run("second put updates in place (no duplicate)", func(t *testing.T) {
		newBlob := []byte{0xAA, 0xBB, 0xCC, 0xDD, 0xEE}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clientsettingsput",
			cidCsPutA, int16(len(newBlob)), newBlob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("update put: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_client_settings WHERE char_id = $1`,
			cidCsPutA).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after update: got %d, want 1 (no duplicate)", rowCnt)
		}

		var (
			gotSize int16
			gotData []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data_size, data FROM user_client_settings WHERE char_id = $1`,
			cidCsPutA).Scan(&gotSize, &gotData); err != nil {
			t.Fatalf("verify update: %v", err)
		}
		if gotSize != int16(len(newBlob)) || !bytes.Equal(gotData, newBlob) {
			t.Fatalf("updated blob mismatch: size=%d data=%x, want size=%d data=%x",
				gotSize, gotData, len(newBlob), newBlob)
		}
	})

	t.Run("max-size 7168 byte blob round-trips", func(t *testing.T) {
		// NCSoft varbinary(7168) cap — confirm BYTEA accepts the original max
		// without truncation or padding. Pattern is i&0xFF so every byte is
		// distinct mod 256; flips a position-dependent zero-fill bug into a
		// visible Scan mismatch.
		bigBlob := make([]byte, 7168)
		for i := range bigBlob {
			bigBlob[i] = byte(i & 0xFF)
		}
		var affected int
		// data_size is SMALLINT (max 32767) — 7168 fits.
		if err := pool.CallSPRow(ctx, "aion_clientsettingsput",
			cidCsPutB, int16(len(bigBlob)), bigBlob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow big: %v", err)
		}
		if affected != 1 {
			t.Fatalf("big put: got %d, want 1", affected)
		}

		var gotData []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_client_settings WHERE char_id = $1`,
			cidCsPutB).Scan(&gotData); err != nil {
			t.Fatalf("verify big: %v", err)
		}
		if !bytes.Equal(gotData, bigBlob) {
			t.Fatalf("7168-byte round-trip failed (len got=%d, want=%d)",
				len(gotData), len(bigBlob))
		}
	})
}
