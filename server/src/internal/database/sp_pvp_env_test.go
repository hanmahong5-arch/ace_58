// Package database — integration test for the pvp_env SP triplet
// (00249 GetPvPEnv / 00250 PutPvPEnv / 00251 DeletePvPEnv).
//
// Domain: world-level PvP relationship registry. NEW domain in batch 23.
// pvp_env is keyed on (type, entity_a, entity_b). PutPvPEnv normalises
// (entity_a < entity_b) on disk; DeletePvPEnv accepts EITHER orientation
// and matches via OR.
//
// Test matrix:
//   - GetPvPEnv on empty table → 0 rows (no implicit defaults)
//   - PutPvPEnv (a < b)  → row stored verbatim
//   - PutPvPEnv (a > b)  → row stored swapped (canonical orientation)
//   - PutPvPEnv (a == b) → self-pair stored (NCSoft pin)
//   - GetPvPEnv after multiple Puts round-trips the canonical pairs
//   - DeletePvPEnv with given orientation removes the canonical row
//   - DeletePvPEnv with reversed orientation also removes (OR predicate)
//   - DeletePvPEnv with no match returns 0
//   - Cross-type isolation: same (a, b) under different `type` is independent
//
// No char_id band needed — pvp_env is world-level, not character-keyed.
// The test uses entity-id band 9_610_001..9_610_099 (the batch's char_id
// band repurposed for entity ids — keeps cleanup hermetic against other
// bands and is documented at the top of each test file in this batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	pvpEntA1   = 9610010
	pvpEntB1   = 9610020
	pvpEntA2   = 9610030
	pvpEntB2   = 9610015 // intentionally < A2 to exercise swap branch
	pvpSelfEnt = 9610040 // self-pair: a == b
	pvpEntC1   = 9610050
	pvpEntC2   = 9610060
	pvpEntD1   = 9610070
	pvpEntD2   = 9610080
	pvpTypeA   = int16(1)
	pvpTypeB   = int16(2)
)

func pvpEnvCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	// pvp_env is world-level (no char_id) — wipe by entity-id band.
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM pvp_env
		  WHERE entity_a BETWEEN 9610001 AND 9610099
		     OR entity_b BETWEEN 9610001 AND 9610099`); err != nil {
		t.Fatalf("pvpEnvCleanup: %v", err)
	}
}

func TestPvPEnv(t *testing.T) {
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

	pvpEnvCleanup(t, ctx, pool)
	t.Cleanup(func() { pvpEnvCleanup(t, context.Background(), pool) })

	t.Run("get on empty band yields no rows in band", func(t *testing.T) {
		// Table-wide rows may exist from prior tests; we must scope by band
		// when verifying. We exercise the SP and count only rows in band.
		rows, err := pool.CallSP(ctx, "aion_getpvpenv")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var bandHits int
		for rows.Next() {
			var typ int16
			var a, b int
			if err := rows.Scan(&typ, &a, &b); err != nil {
				t.Fatalf("scan: %v", err)
			}
			if (a >= 9610001 && a <= 9610099) || (b >= 9610001 && b <= 9610099) {
				bandHits++
			}
		}
		if bandHits != 0 {
			t.Fatalf("pre-test band-hit rows: got %d, want 0", bandHits)
		}
	})

	t.Run("put a<b stores verbatim (no swap)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_putpvpenv",
			pvpTypeA, int(pvpEntA1), int(pvpEntB1)); err != nil {
			t.Fatalf("CallSPExec put a<b: %v", err)
		}
		var a, b int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT entity_a, entity_b FROM pvp_env
			  WHERE type = $1 AND entity_a = $2`,
			pvpTypeA, pvpEntA1).Scan(&a, &b); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if a != pvpEntA1 || b != pvpEntB1 {
			t.Fatalf("a<b store: got (%d,%d), want (%d,%d)",
				a, b, pvpEntA1, pvpEntB1)
		}
	})

	t.Run("put a>b swaps to canonical (a,b)=(min,max)", func(t *testing.T) {
		// Caller passes (pvpEntA2=9610030, pvpEntB2=9610015) with a > b;
		// canonical orientation must store (entity_a=9610015, entity_b=9610030).
		if err := pool.CallSPExec(ctx, "aion_putpvpenv",
			pvpTypeA, int(pvpEntA2), int(pvpEntB2)); err != nil {
			t.Fatalf("CallSPExec put a>b: %v", err)
		}
		var a, b int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT entity_a, entity_b FROM pvp_env
			  WHERE type = $1 AND entity_a = $2 AND entity_b = $3`,
			pvpTypeA, pvpEntB2, pvpEntA2).Scan(&a, &b); err != nil {
			t.Fatalf("verify swap: %v", err)
		}
		if a != pvpEntB2 || b != pvpEntA2 {
			t.Fatalf("swap result: got (%d,%d), want (%d,%d) — canonical",
				a, b, pvpEntB2, pvpEntA2)
		}
	})

	t.Run("put a==b self-pair stored (NCSoft pin)", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_putpvpenv",
			pvpTypeA, int(pvpSelfEnt), int(pvpSelfEnt)); err != nil {
			t.Fatalf("CallSPExec self-pair: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM pvp_env
			  WHERE type = $1 AND entity_a = $2 AND entity_b = $2`,
			pvpTypeA, pvpSelfEnt).Scan(&n); err != nil {
			t.Fatalf("verify self: %v", err)
		}
		if n != 1 {
			t.Fatalf("self-pair count: got %d, want 1 (NCSoft pin)", n)
		}
	})

	t.Run("get returns all canonical rows in band", func(t *testing.T) {
		// After the three Puts above we expect 3 rows in band:
		//   (typeA, A1, B1), (typeA, B2, A2 swapped), (typeA, self, self).
		rows, err := pool.CallSP(ctx, "aion_getpvpenv")
		if err != nil {
			t.Fatalf("CallSP get: %v", err)
		}
		defer rows.Close()
		seen := make(map[[3]int]struct{}, 3)
		for rows.Next() {
			var typ int16
			var a, b int
			if err := rows.Scan(&typ, &a, &b); err != nil {
				t.Fatalf("scan: %v", err)
			}
			// Filter to band entries this test owns.
			if (a >= 9610001 && a <= 9610099) || (b >= 9610001 && b <= 9610099) {
				seen[[3]int{int(typ), a, b}] = struct{}{}
			}
		}
		want := map[[3]int]struct{}{
			{int(pvpTypeA), pvpEntA1, pvpEntB1}:     {},
			{int(pvpTypeA), pvpEntB2, pvpEntA2}:     {}, // swapped form
			{int(pvpTypeA), pvpSelfEnt, pvpSelfEnt}: {},
		}
		if len(seen) != len(want) {
			t.Fatalf("get rows in band: got %d, want %d (seen=%v)",
				len(seen), len(want), seen)
		}
		for k := range want {
			if _, ok := seen[k]; !ok {
				t.Fatalf("missing row %v in get result", k)
			}
		}
	})

	t.Run("delete with original orientation removes (a<b path)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletepvpenv",
			pvpTypeA, int(pvpEntA1), int(pvpEntB1)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow del: %v", err)
		}
		if affected != 1 {
			t.Fatalf("delete a<b: got %d, want 1", affected)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM pvp_env
			  WHERE type = $1 AND entity_a = $2 AND entity_b = $3`,
			pvpTypeA, pvpEntA1, pvpEntB1).Scan(&n); err != nil {
			t.Fatalf("verify delete: %v", err)
		}
		if n != 0 {
			t.Fatalf("after delete: got %d rows, want 0", n)
		}
	})

	t.Run("delete with reversed orientation matches via OR (NCSoft pin)", func(t *testing.T) {
		// Disk row is (entity_a=pvpEntB2, entity_b=pvpEntA2) — caller
		// supplies the OPPOSITE order (pvpEntA2, pvpEntB2); the OR
		// predicate must still match.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletepvpenv",
			pvpTypeA, int(pvpEntA2), int(pvpEntB2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow del-reversed: %v", err)
		}
		if affected != 1 {
			t.Fatalf("delete reversed: got %d, want 1 (OR-predicate pin)", affected)
		}
	})

	t.Run("delete with no match returns 0", func(t *testing.T) {
		// pvpEntC1/C2 never inserted.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletepvpenv",
			pvpTypeA, int(pvpEntC1), int(pvpEntC2)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow del-miss: %v", err)
		}
		if affected != 0 {
			t.Fatalf("delete miss: got %d, want 0", affected)
		}
	})

	t.Run("cross-type isolation: (a,b) under different type is independent", func(t *testing.T) {
		// Put (typeA, D1, D2) and (typeB, D1, D2). Delete (typeA, D1, D2)
		// must not touch the typeB row.
		if err := pool.CallSPExec(ctx, "aion_putpvpenv",
			pvpTypeA, int(pvpEntD1), int(pvpEntD2)); err != nil {
			t.Fatalf("seed typeA: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_putpvpenv",
			pvpTypeB, int(pvpEntD1), int(pvpEntD2)); err != nil {
			t.Fatalf("seed typeB: %v", err)
		}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletepvpenv",
			pvpTypeA, int(pvpEntD1), int(pvpEntD2)).Scan(&affected); err != nil {
			t.Fatalf("del typeA: %v", err)
		}
		if affected != 1 {
			t.Fatalf("typeA del: got %d, want 1", affected)
		}
		// Verify typeB row survived untouched.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM pvp_env
			  WHERE type = $1 AND entity_a = $2 AND entity_b = $3`,
			pvpTypeB, pvpEntD1, pvpEntD2).Scan(&n); err != nil {
			t.Fatalf("verify typeB: %v", err)
		}
		if n != 1 {
			t.Fatalf("typeB cross-leak: got %d rows, want 1", n)
		}
	})
}
