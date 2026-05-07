// Package database — integration test for the SpawnAreaRank SP triplet
// (00266 GetSpawnAreaRankList / 00267 SetSpawnAreaRank / 00268 DeleteSpawnAreaRank).
//
// Domain: world-level spawn area rank tier (1 byte). NEW domain in batch 26.
// The triplet upserts/deletes on `spawn_area_rank` keyed on
// (world_no, spawn_area_name). spawn_area_name is case-sensitive in PG
// (NCSoft divergence, documented on 00267).
//
// Test matrix:
//   - GetList on empty band → 0 in-band rows (table-wide rows ignored)
//   - Set fresh (world, name) → row inserted with given rank
//   - Set existing → rank updated, row count unchanged
//   - Set with rank=0 → 0 stored (boundary: tinyint min)
//   - Set with rank=255 → 255 stored (boundary: tinyint max)
//   - GetList includes all in-band rows after multiple Sets
//   - Delete present row → returns 1, row gone
//   - Delete missing row → returns 0, no error
//   - World isolation: same name under different world is independent
//   - Case sensitivity: "Foo" and "foo" are distinct rows (PG divergence pin)
//
// Cleanup: world_no band 99_660_001..99_660_099 (R26 batch's reserved
// band, repurposed for world ids since spawn_area_rank is world-keyed
// not character-keyed).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	sarWorldA = 99660010
	sarWorldB = 99660020
	sarWorldC = 99660030
	sarNameA  = "AreaAlpha"
	sarNameB  = "AreaBeta"
	sarNameC  = "AreaGamma"
	sarNameD  = "AreaDelta"
	sarNameE  = "AreaEpsilon"
	sarNameF  = "AreaZeta"
)

// sarCleanup wipes the R26 world_no band from spawn_area_rank.
// Idempotent — safe to call before AND after the test.
func sarCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM spawn_area_rank
		  WHERE world_no BETWEEN 99660001 AND 99660099`); err != nil {
		t.Fatalf("sarCleanup: %v", err)
	}
}

func TestSpawnAreaRank(t *testing.T) {
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

	sarCleanup(t, ctx, pool)
	t.Cleanup(func() { sarCleanup(t, context.Background(), pool) })

	// countInBand walks the SP-returned rows and tallies only those whose
	// world_no falls inside the R26 band so we don't trip on rows seeded
	// by other tests in shared tables.
	countInBand := func(t *testing.T) (int, map[[2]any]int16) {
		t.Helper()
		rows, err := pool.CallSP(ctx, "aion_getspawnarearanklist")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		seen := make(map[[2]any]int16)
		var inBand int
		for rows.Next() {
			var worldNo int
			var name string
			var rank int16
			if err := rows.Scan(&worldNo, &name, &rank); err != nil {
				t.Fatalf("scan: %v", err)
			}
			if worldNo >= 99660001 && worldNo <= 99660099 {
				inBand++
				seen[[2]any{worldNo, name}] = rank
			}
		}
		return inBand, seen
	}

	t.Run("get list on empty band yields 0 in-band rows", func(t *testing.T) {
		inBand, _ := countInBand(t)
		if inBand != 0 {
			t.Fatalf("pre-test in-band rows: got %d, want 0", inBand)
		}
	})

	t.Run("set fresh (world, name) inserts row", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldA, sarNameA, int16(50)); err != nil {
			t.Fatalf("CallSPExec set fresh: %v", err)
		}
		var rank int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name = $2`,
			sarWorldA, sarNameA).Scan(&rank); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if rank != 50 {
			t.Fatalf("rank: got %d, want 50", rank)
		}
	})

	t.Run("set existing updates rank, row count unchanged", func(t *testing.T) {
		// Re-set the row inserted above with a new rank.
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldA, sarNameA, int16(99)); err != nil {
			t.Fatalf("CallSPExec update: %v", err)
		}
		var rank int16
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank, (SELECT COUNT(*) FROM spawn_area_rank
			               WHERE world_no = $1 AND spawn_area_name = $2)
			   FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name = $2`,
			sarWorldA, sarNameA).Scan(&rank, &n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if rank != 99 {
			t.Fatalf("updated rank: got %d, want 99", rank)
		}
		if n != 1 {
			t.Fatalf("row count: got %d, want 1 (no duplicate from upsert)", n)
		}
	})

	t.Run("set boundary ranks (0 and 255) round-trip", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldA, sarNameB, int16(0)); err != nil {
			t.Fatalf("CallSPExec rank=0: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldA, sarNameC, int16(255)); err != nil {
			t.Fatalf("CallSPExec rank=255: %v", err)
		}
		var lo, hi int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name = $2`,
			sarWorldA, sarNameB).Scan(&lo); err != nil {
			t.Fatalf("verify lo: %v", err)
		}
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name = $2`,
			sarWorldA, sarNameC).Scan(&hi); err != nil {
			t.Fatalf("verify hi: %v", err)
		}
		if lo != 0 {
			t.Fatalf("rank=0: got %d, want 0", lo)
		}
		if hi != 255 {
			t.Fatalf("rank=255: got %d, want 255", hi)
		}
	})

	t.Run("get list returns all in-band rows", func(t *testing.T) {
		// At this point the band holds:
		//   (sarWorldA, sarNameA, 99)
		//   (sarWorldA, sarNameB, 0)
		//   (sarWorldA, sarNameC, 255)
		inBand, seen := countInBand(t)
		if inBand != 3 {
			t.Fatalf("in-band rows: got %d, want 3 (seen=%v)", inBand, seen)
		}
		want := map[[2]any]int16{
			{sarWorldA, sarNameA}: 99,
			{sarWorldA, sarNameB}: 0,
			{sarWorldA, sarNameC}: 255,
		}
		for k, v := range want {
			if seen[k] != v {
				t.Fatalf("row %v: got rank %d, want %d", k, seen[k], v)
			}
		}
	})

	t.Run("delete present row returns 1, row gone", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletespawnarearank",
			sarWorldA, sarNameA).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow delete: %v", err)
		}
		if affected != 1 {
			t.Fatalf("delete present: got %d, want 1", affected)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name = $2`,
			sarWorldA, sarNameA).Scan(&n); err != nil {
			t.Fatalf("verify gone: %v", err)
		}
		if n != 0 {
			t.Fatalf("after delete: got %d rows, want 0", n)
		}
	})

	t.Run("delete missing row returns 0, no error", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletespawnarearank",
			sarWorldA, sarNameD).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow delete miss: %v", err)
		}
		if affected != 0 {
			t.Fatalf("delete miss: got %d, want 0", affected)
		}
	})

	t.Run("world isolation: same name under different worlds independent", func(t *testing.T) {
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldB, sarNameE, int16(11)); err != nil {
			t.Fatalf("CallSPExec B: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldC, sarNameE, int16(22)); err != nil {
			t.Fatalf("CallSPExec C: %v", err)
		}
		// Delete only B; C must remain.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deletespawnarearank",
			sarWorldB, sarNameE).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow del B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("del B: got %d, want 1", affected)
		}
		var rankC int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT rank FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name = $2`,
			sarWorldC, sarNameE).Scan(&rankC); err != nil {
			t.Fatalf("verify C survives: %v", err)
		}
		if rankC != 22 {
			t.Fatalf("C survived rank: got %d, want 22", rankC)
		}
	})

	t.Run("case sensitivity: 'Foo' and 'foo' are distinct rows (PG divergence pin)", func(t *testing.T) {
		// PG VARCHAR is case-sensitive by default; NCSoft used SQL Server
		// case-insensitive collation. The SP migration documents this as
		// a known divergence and the caller must normalise. This test
		// pins the divergence so any future CITEXT switch is a deliberate
		// breaking change.
		upper := sarNameF       // "AreaZeta"
		lower := "areazeta"     // same word, lowercase
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldB, upper, int16(1)); err != nil {
			t.Fatalf("CallSPExec upper: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setspawnarearank",
			sarWorldB, lower, int16(2)); err != nil {
			t.Fatalf("CallSPExec lower: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM spawn_area_rank
			  WHERE world_no = $1 AND spawn_area_name IN ($2, $3)`,
			sarWorldB, upper, lower).Scan(&n); err != nil {
			t.Fatalf("verify case: %v", err)
		}
		if n != 2 {
			t.Fatalf("case rows: got %d, want 2 (PG case-sensitive pin)", n)
		}
	})
}
