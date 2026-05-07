// Package database — integration tests for the error_ignore SP pair
// (00232 addErrorIgnore / 00233 LoadErrorIgnoreList).
//
// Domain: client-side error suppression list, first introduced in batch 19.
// Single TEXT key column (`ignore`) with UNIQUE + dedup-on-conflict.
//
// Test matrix:
//   - addErrorIgnore inserts fresh key, returns 1
//   - addErrorIgnore on existing key returns 0 (dedup pin)
//   - LoadErrorIgnoreList returns ordered (id ASC) full set
//   - case sensitivity pin (CS PG vs CI T-SQL — documented divergence)
//
// char_id band: N/A — this domain has no char_id; we use a key-prefix band
// `r19_eig_*` for cleanup isolation.
package database

import (
	"context"
	"testing"
	"time"
)

// errorIgnoreCleanup wipes the band before & after to keep tests hermetic.
// Domain has no char_id; we scope by `ignore` LIKE prefix.
func errorIgnoreCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM error_ignore WHERE ignore LIKE 'r19_eig_%'`); err != nil {
		t.Fatalf("errorIgnoreCleanup: %v", err)
	}
}

func TestErrorIgnoreList(t *testing.T) {
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

	errorIgnoreCleanup(t, ctx, pool)
	t.Cleanup(func() { errorIgnoreCleanup(t, context.Background(), pool) })

	t.Run("add fresh key returns 1 (insert branch)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_adderrorignore",
			"r19_eig_alpha").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1 (fresh insert)", affected)
		}

		// Confirm row exists with that exact key.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM error_ignore WHERE ignore=$1`,
			"r19_eig_alpha").Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 1 {
			t.Fatalf("row count: got %d, want 1", n)
		}
	})

	t.Run("add duplicate key returns 0 (dedup pin)", func(t *testing.T) {
		// First call seeds, second must be a no-op.
		var first, second int
		if err := pool.CallSPRow(ctx, "aion_adderrorignore",
			"r19_eig_dup").Scan(&first); err != nil {
			t.Fatalf("first call: %v", err)
		}
		if first != 1 {
			t.Fatalf("first affected: got %d, want 1", first)
		}
		if err := pool.CallSPRow(ctx, "aion_adderrorignore",
			"r19_eig_dup").Scan(&second); err != nil {
			t.Fatalf("second call: %v", err)
		}
		if second != 0 {
			t.Fatalf("duplicate affected: got %d, want 0 (dedup pin)", second)
		}

		// Still exactly 1 row with that key.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM error_ignore WHERE ignore=$1`,
			"r19_eig_dup").Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 1 {
			t.Fatalf("row count after dup: got %d, want 1", n)
		}
	})

	t.Run("case sensitivity pin: alpha != ALPHA on PG (documented divergence from T-SQL CI)", func(t *testing.T) {
		// PG default collation is binary / case-sensitive. NCSoft T-SQL
		// column collation was Latin1_General_CI_AS (case-insensitive),
		// so under T-SQL "Alpha" would have been deduped against
		// "alpha". We pin the safer CS behaviour and document divergence.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_adderrorignore",
			"r19_eig_BETA").Scan(&affected); err != nil {
			t.Fatalf("first BETA: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first BETA affected: got %d, want 1", affected)
		}
		// Different case — must INSERT (CS pin).
		if err := pool.CallSPRow(ctx, "aion_adderrorignore",
			"r19_eig_beta").Scan(&affected); err != nil {
			t.Fatalf("second beta: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second beta affected: got %d, want 1 (case-sensitive pin)", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM error_ignore WHERE ignore IN ($1,$2)`,
			"r19_eig_BETA", "r19_eig_beta").Scan(&n); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if n != 2 {
			t.Fatalf("CS row count: got %d, want 2 (CS divergence pin)", n)
		}
	})

	t.Run("load list returns full ordered set (band rows preserve insertion order)", func(t *testing.T) {
		// Pre-clean band rows (this subtest must run after the seeders
		// above so we're loading a known multi-row set; we re-seed to
		// keep the subtest order-independent). errorIgnoreCleanup is
		// called by the parent test cleanup chain; here we DELETE and
		// re-seed in a known sequence.
		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM error_ignore WHERE ignore LIKE 'r19_eig_load_%'`); err != nil {
			t.Fatalf("pre-clean: %v", err)
		}

		// Insert in a deterministic order to verify ORDER BY id ASC.
		seeds := []string{
			"r19_eig_load_001",
			"r19_eig_load_002",
			"r19_eig_load_003",
		}
		for _, s := range seeds {
			if err := pool.CallSPExec(ctx, "aion_adderrorignore", s); err != nil {
				t.Fatalf("seed %q: %v", s, err)
			}
		}

		// LoadErrorIgnoreList returns full table ordered by id ASC. We
		// scan and filter to band, asserting both presence and that the
		// band-prefixed keys appear in the order they were inserted.
		rows, err := pool.CallSP(ctx, "aion_loaderrorignorelist")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		var loaded []string
		var lastID int64
		for rows.Next() {
			var id int64
			var key string
			if err := rows.Scan(&id, &key); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			// id MUST be monotonic non-decreasing (ORDER BY id ASC pin).
			// Use < (not <=) to allow same-id never-collide via UNIQUE seq.
			if id < lastID {
				t.Fatalf("id ordering broken: id=%d < lastID=%d", id, lastID)
			}
			lastID = id
			// Filter to our band so concurrent rows don't pollute the assert.
			if len(key) >= len("r19_eig_load_") && key[:len("r19_eig_load_")] == "r19_eig_load_" {
				loaded = append(loaded, key)
			}
		}

		if len(loaded) != len(seeds) {
			t.Fatalf("loaded band count: got %d, want %d", len(loaded), len(seeds))
		}
		// Insertion order preserved by id-ascending sort.
		for i, want := range seeds {
			if loaded[i] != want {
				t.Fatalf("order[%d]: got %q, want %q", i, loaded[i], want)
			}
		}
	})
}
