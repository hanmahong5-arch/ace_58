// Package database — integration test for aion_PutItemCoolTime (single-row
// blob upsert; sister write of 00166 GetItemCoolTime).
//
// PG side semantics:
//   - First call inserts (cooltime_data_cnt, data) blob keyed by char_id PK.
//   - Subsequent calls UPDATE in place — verified by reading back via the
//     read-side SP aion_GetItemCoolTime AND a direct table SELECT.
//   - Distinct char_ids coexist (no PK collision).
//   - Empty blob (zero-length BYTEA) is accepted — pinned bug-for-bug.
//   - cnt and data are caller-trusted (no cross-validation).
//
// char_id band: 9_600_001..9_600_019 (batch 22 — item_cooltime sub-band).
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	cidPItemCT_A     = 9600001 // first-call → INSERT
	cidPItemCT_B     = 9600002 // distinct char coexists
	cidPItemCT_Edge  = 9600003 // empty blob
	cidPItemCT_Updt  = 9600004 // first-INSERT then UPDATE in place
	cidPItemCT_Big   = 9600005 // 1024-byte blob (NCSoft client ceiling)
)

func putItemCoolTimeCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_cooltime WHERE char_id BETWEEN 9600001 AND 9600019`); err != nil {
		t.Fatalf("putItemCoolTimeCleanup: %v", err)
	}
}

func TestPutItemCoolTime(t *testing.T) {
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

	putItemCoolTimeCleanup(t, ctx, pool)
	t.Cleanup(func() { putItemCoolTimeCleanup(t, context.Background(), pool) })

	t.Run("first call inserts a row, payload round-trips", func(t *testing.T) {
		blob := []byte{0x01, 0x02, 0x03, 0x04, 0x05}
		if err := pool.CallSPExec(ctx, "aion_putitemcooltime",
			cidPItemCT_A, int16(2), blob); err != nil {
			t.Fatalf("CallSP insert: %v", err)
		}

		var (
			cnt  int16
			data []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cooltime_data_cnt, data FROM user_item_cooltime WHERE char_id=$1`,
			cidPItemCT_A).Scan(&cnt, &data); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cnt != 2 || !bytes.Equal(data, blob) {
			t.Fatalf("payload: cnt=%d data=%x, want 2/%x", cnt, data, blob)
		}
	})

	t.Run("second call on same char_id UPDATEs in place (no second row)", func(t *testing.T) {
		// First insert.
		if err := pool.CallSPExec(ctx, "aion_putitemcooltime",
			cidPItemCT_Updt, int16(1), []byte{0xAA}); err != nil {
			t.Fatalf("first insert: %v", err)
		}

		// Second call — should UPDATE (ON CONFLICT DO UPDATE).
		blob2 := []byte{0xBB, 0xCC, 0xDD}
		if err := pool.CallSPExec(ctx, "aion_putitemcooltime",
			cidPItemCT_Updt, int16(3), blob2); err != nil {
			t.Fatalf("second update: %v", err)
		}

		// Verify exactly 1 row, with the SECOND payload.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_cooltime WHERE char_id=$1`,
			cidPItemCT_Updt).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("row count after upsert: got %d, want 1", n)
		}

		var (
			cnt  int16
			data []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cooltime_data_cnt, data FROM user_item_cooltime WHERE char_id=$1`,
			cidPItemCT_Updt).Scan(&cnt, &data); err != nil {
			t.Fatalf("verify upsert: %v", err)
		}
		if cnt != 3 || !bytes.Equal(data, blob2) {
			t.Fatalf("upsert payload: cnt=%d data=%x, want 3/%x", cnt, data, blob2)
		}
	})

	t.Run("distinct char_ids coexist (no PK collision)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_putitemcooltime",
			cidPItemCT_B, int16(7), []byte{0x10, 0x20}); err != nil {
			t.Fatalf("char B: %v", err)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_cooltime WHERE char_id IN ($1, $2)`,
			cidPItemCT_A, cidPItemCT_B).Scan(&n); err != nil {
			t.Fatalf("count distinct: %v", err)
		}
		if n != 2 {
			t.Fatalf("distinct chars: got %d rows, want 2", n)
		}
	})

	t.Run("empty blob is accepted (NCSoft contract)", func(t *testing.T) {
		// NCSoft varbinary(1024) accepts a zero-length blob; PG BYTEA does too.
		if err := pool.CallSPExec(ctx, "aion_putitemcooltime",
			cidPItemCT_Edge, int16(0), []byte{}); err != nil {
			t.Fatalf("empty blob: %v", err)
		}
		var (
			cnt  int16
			data []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cooltime_data_cnt, data FROM user_item_cooltime WHERE char_id=$1`,
			cidPItemCT_Edge).Scan(&cnt, &data); err != nil {
			t.Fatalf("verify empty: %v", err)
		}
		if cnt != 0 || len(data) != 0 {
			t.Fatalf("empty edge: cnt=%d datalen=%d, want 0/0", cnt, len(data))
		}
	})

	t.Run("1024-byte blob round-trips (NCSoft client ceiling)", func(t *testing.T) {
		blob := make([]byte, 1024)
		for i := range blob {
			blob[i] = byte(i % 256)
		}
		if err := pool.CallSPExec(ctx, "aion_putitemcooltime",
			cidPItemCT_Big, int16(128), blob); err != nil {
			t.Fatalf("1024-byte blob: %v", err)
		}
		var data []byte
		if err := pool.Inner().QueryRow(ctx,
			`SELECT data FROM user_item_cooltime WHERE char_id=$1`,
			cidPItemCT_Big).Scan(&data); err != nil {
			t.Fatalf("verify 1024: %v", err)
		}
		if !bytes.Equal(data, blob) {
			t.Fatalf("1024 round-trip: len=%d, want 1024", len(data))
		}
	})
}
