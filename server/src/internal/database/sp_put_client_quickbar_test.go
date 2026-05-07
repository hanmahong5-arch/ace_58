// Package database — integration test for aion_PutClientQuickBar.
//
// 1:1 char→blob hotbar UPSERT keyed on PK char_id. Both insert and update
// branches return ROW_COUNT=1.
//
// Test matrix:
//   - happy path: first put on a fresh char inserts 1 row, blob round-trips
//   - rebind: second put with same char_id replaces blob in place
//   - empty blob: zero-byte payload accepted (gateway sometimes sends empties)
//   - large blob: 7168-byte payload (NCSoft signature ceiling) accepted
//   - neighbour isolation: putting on A doesn't perturb B's blob
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidQuickbarA = 9480001
	cidQuickbarB = 9480002
)

func putClientQuickbarCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_quickbar WHERE char_id BETWEEN 9480001 AND 9480099`); err != nil {
		t.Fatalf("putClientQuickbarCleanup user_client_quickbar: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9480001 AND 9480099`); err != nil {
		t.Fatalf("putClientQuickbarCleanup user_data: %v", err)
	}
}

func TestPutClientQuickBar(t *testing.T) {
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

	putClientQuickbarCleanup(t, ctx, pool)
	t.Cleanup(func() { putClientQuickbarCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidQuickbarA, "QbA"},
		{cidQuickbarB, "QbB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "qb_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: insert branch returns 1 and blob round-trips", func(t *testing.T) {
		blob := []byte{0x01, 0x02, 0x03, 0xDE, 0xAD, 0xBE, 0xEF}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putclientquickbar",
			cidQuickbarA, int16(len(blob)), blob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var (
			gotSize int16
			gotBlob []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data_size, data FROM user_client_quickbar WHERE char_id = $1`,
			cidQuickbarA).Scan(&gotSize, &gotBlob); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if int(gotSize) != len(blob) {
			t.Fatalf("size: got %d, want %d", gotSize, len(blob))
		}
		if !bytes.Equal(gotBlob, blob) {
			t.Fatalf("blob: got %x, want %x", gotBlob, blob)
		}
	})

	t.Run("rebind: update branch replaces blob, still 1 row", func(t *testing.T) {
		newBlob := []byte{0xCA, 0xFE, 0xBA, 0xBE}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putclientquickbar",
			cidQuickbarA, int16(len(newBlob)), newBlob).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow rebind: %v", err)
		}
		if affected != 1 {
			t.Fatalf("rebind: got %d, want 1", affected)
		}

		// Still exactly 1 row for this char (UPSERT, not INSERT-twice).
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_client_quickbar WHERE char_id = $1`,
			cidQuickbarA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rebind cnt: got %d, want 1", cnt)
		}

		var (
			gotSize int16
			gotBlob []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data_size, data FROM user_client_quickbar WHERE char_id = $1`,
			cidQuickbarA).Scan(&gotSize, &gotBlob); err != nil {
			t.Fatalf("verify rebind: %v", err)
		}
		if int(gotSize) != len(newBlob) || !bytes.Equal(gotBlob, newBlob) {
			t.Fatalf("rebind blob/size: got %x/%d, want %x/%d",
				gotBlob, gotSize, newBlob, len(newBlob))
		}
	})

	t.Run("empty blob: zero-byte payload accepted", func(t *testing.T) {
		empty := []byte{}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putclientquickbar",
			cidQuickbarA, int16(0), empty).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow empty: %v", err)
		}
		if affected != 1 {
			t.Fatalf("empty: got %d, want 1", affected)
		}

		var (
			gotSize int16
			gotBlob []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data_size, data FROM user_client_quickbar WHERE char_id = $1`,
			cidQuickbarA).Scan(&gotSize, &gotBlob); err != nil {
			t.Fatalf("verify empty: %v", err)
		}
		if gotSize != 0 || len(gotBlob) != 0 {
			t.Fatalf("empty post-state: size=%d blob=%v", gotSize, gotBlob)
		}
	})

	t.Run("large blob: 7168 bytes (NCSoft signature ceiling) accepted", func(t *testing.T) {
		big := make([]byte, 7168)
		for i := range big {
			big[i] = byte(i & 0xFF)
		}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putclientquickbar",
			cidQuickbarA, int16(len(big)), big).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow big: %v", err)
		}
		if affected != 1 {
			t.Fatalf("big: got %d, want 1", affected)
		}

		var gotBlob []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_client_quickbar WHERE char_id = $1`,
			cidQuickbarA).Scan(&gotBlob); err != nil {
			t.Fatalf("verify big: %v", err)
		}
		if len(gotBlob) != 7168 || !bytes.Equal(gotBlob, big) {
			t.Fatalf("big roundtrip: len=%d, equal=%t", len(gotBlob), bytes.Equal(gotBlob, big))
		}
	})

	t.Run("neighbour isolation: B blob persists when A is rewritten", func(t *testing.T) {
		bBlob := []byte{0xBB, 0xBB, 0xBB}
		if err := pool.CallSPExec(ctx, "aion_putclientquickbar",
			cidQuickbarB, int16(len(bBlob)), bBlob); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}

		// Rewrite A — must not perturb B.
		newA := []byte{0xAA, 0xAA}
		if err := pool.CallSPExec(ctx, "aion_putclientquickbar",
			cidQuickbarA, int16(len(newA)), newA); err != nil {
			t.Fatalf("CallSPExec A overwrite: %v", err)
		}

		var gotB []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_client_quickbar WHERE char_id = $1`,
			cidQuickbarB).Scan(&gotB); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if !bytes.Equal(gotB, bBlob) {
			t.Fatalf("B leaked from A: got %x, want %x", gotB, bBlob)
		}
	})
}
