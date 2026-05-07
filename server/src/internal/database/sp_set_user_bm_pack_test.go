// Package database — integration test for aion_SetUserBMPack.
//
// Upsert with NCSoft asymmetry: INSERT forces pack_state=1; UPDATE honours
// the caller's pack_state. Verifies: insert path forces state=1 even when
// caller passes 7; update path overwrites both state and expiration_time;
// per-(char_id, pack_type) isolation; multiple update calls leave only the
// last value (no row duplication).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidBMSetFresh    = 9001300 // no row → tests INSERT branch
	cidBMSetUpdate   = 9001301 // pre-existing row → tests UPDATE branch
	cidBMSetIdempot  = 9001302 // multiple SET calls → still 1 row, last wins
	cidBMSetNeighbor = 9001303 // neighbour to verify isolation
)

func userBMPackSetCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_bm_pack WHERE char_id BETWEEN 9001300 AND 9001399`); err != nil {
		t.Fatalf("userBMPackSetCleanup user_bm_pack: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001300 AND 9001399`); err != nil {
		t.Fatalf("userBMPackSetCleanup user_data: %v", err)
	}
}

// helper: reads back a single row's (state, expiration) directly via SQL so the
// test doesn't depend on the partner SP's state filter.
func readBMPackRow(t *testing.T, ctx context.Context, p *Pool, charID, packType int) (state int, expire int, ok bool) {
	t.Helper()
	rows, err := p.Inner().Query(ctx,
		`SELECT pack_state, expiration_time FROM user_bm_pack
		  WHERE char_id = $1 AND pack_type = $2`,
		charID, packType)
	if err != nil {
		t.Fatalf("readBMPackRow: %v", err)
	}
	defer rows.Close()
	if !rows.Next() {
		return 0, 0, false
	}
	var s, e int
	if err := rows.Scan(&s, &e); err != nil {
		t.Fatalf("readBMPackRow Scan: %v", err)
	}
	return s, e, true
}

func TestSetUserBMPack(t *testing.T) {
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

	userBMPackSetCleanup(t, ctx, pool)
	t.Cleanup(func() { userBMPackSetCleanup(t, context.Background(), pool) })

	for _, cid := range []int{cidBMSetFresh, cidBMSetUpdate, cidBMSetIdempot, cidBMSetNeighbor} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1::INT, 'bmset_'||$1::INT::TEXT, 'bs_'||$1::INT::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	t.Run("INSERT branch forces pack_state=1", func(t *testing.T) {
		// Caller asks for state=7, but INSERT must clamp it to 1.
		if err := pool.CallSPExec(ctx, "aion_setuserbmpack",
			cidBMSetFresh, 12, 7, 1700000000); err != nil {
			t.Fatalf("CallSPExec INSERT: %v", err)
		}
		s, e, ok := readBMPackRow(t, ctx, pool, cidBMSetFresh, 12)
		if !ok {
			t.Fatal("INSERT path: no row written")
		}
		if s != 1 || e != 1700000000 {
			t.Fatalf("INSERT path: state=%d expire=%d, want state=1 expire=1700000000", s, e)
		}
	})

	t.Run("UPDATE branch honours caller pack_state and expiration", func(t *testing.T) {
		// Pre-seed a row in state=1.
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_bm_pack(char_id, pack_type, pack_state, expiration_time)
			 VALUES ($1, 20, 1, 1700000000)`,
			cidBMSetUpdate); err != nil {
			t.Fatalf("seed update: %v", err)
		}
		// Now SET with state=3, new expiration.
		if err := pool.CallSPExec(ctx, "aion_setuserbmpack",
			cidBMSetUpdate, 20, 3, 1800000000); err != nil {
			t.Fatalf("CallSPExec UPDATE: %v", err)
		}
		s, e, ok := readBMPackRow(t, ctx, pool, cidBMSetUpdate, 20)
		if !ok {
			t.Fatal("UPDATE path: row vanished")
		}
		if s != 3 || e != 1800000000 {
			t.Fatalf("UPDATE path: state=%d expire=%d, want state=3 expire=1800000000", s, e)
		}
	})

	t.Run("idempotent across multiple calls (no duplicate rows)", func(t *testing.T) {
		// First call: INSERT branch, state forced to 1.
		if err := pool.CallSPExec(ctx, "aion_setuserbmpack",
			cidBMSetIdempot, 30, 9, 1701000000); err != nil {
			t.Fatalf("CallSPExec call 1: %v", err)
		}
		// Second call: UPDATE branch, state honoured.
		if err := pool.CallSPExec(ctx, "aion_setuserbmpack",
			cidBMSetIdempot, 30, 5, 1702000000); err != nil {
			t.Fatalf("CallSPExec call 2: %v", err)
		}
		// Third call: UPDATE branch again.
		if err := pool.CallSPExec(ctx, "aion_setuserbmpack",
			cidBMSetIdempot, 30, 6, 1703000000); err != nil {
			t.Fatalf("CallSPExec call 3: %v", err)
		}
		// Verify exactly one row, last value wins.
		var count int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_bm_pack WHERE char_id = $1 AND pack_type = $2`,
			cidBMSetIdempot, 30).Scan(&count); err != nil {
			t.Fatalf("count: %v", err)
		}
		if count != 1 {
			t.Fatalf("idempotent: row count=%d, want 1", count)
		}
		s, e, _ := readBMPackRow(t, ctx, pool, cidBMSetIdempot, 30)
		if s != 6 || e != 1703000000 {
			t.Fatalf("idempotent last-wins: state=%d expire=%d, want state=6 expire=1703000000", s, e)
		}
	})

	t.Run("isolation: write to one (char,type) does not touch neighbours", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setuserbmpack",
			cidBMSetNeighbor, 40, 1, 1900000000); err != nil {
			t.Fatalf("CallSPExec neighbour: %v", err)
		}
		// Earlier Fresh/Update/Idempot rows must remain untouched.
		s, e, ok := readBMPackRow(t, ctx, pool, cidBMSetFresh, 12)
		if !ok || s != 1 || e != 1700000000 {
			t.Fatalf("isolation: cidBMSetFresh row drifted (state=%d expire=%d ok=%v)", s, e, ok)
		}
	})
}
