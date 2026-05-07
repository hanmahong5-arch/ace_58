// Package database — integration test for aion_SetTitle.
//
// Pure UPDATE on user_data PK(char_id), setting cur_title_id and bumping
// change_info_time = GetUnixtimeWithUTCAdjust(NOW(),0). Returns
// rows-affected: 1 on success, 0 if char missing (NCSoft @@ROWCOUNT pin).
// No catalog FK on cur_title_id; 0 / negative title ids accepted.
//
// Test matrix:
//   - existing char: 1 row affected, cur_title_id round-trips, change_info_time bumped
//   - missing char: 0 rows affected, no error
//   - title 0 = "no title equipped" sentinel accepted
//   - negative title id accepted (GM/dev flag pin)
//   - re-setting same value still bumps change_info_time (cache invalidate)
//
// char_id band: 9_550_041..9_550_049 (R17 batch — title-write subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidStA       = 9550041
	cidStB       = 9550042
	cidStNeg     = 9550043
	cidStBump    = 9550044 // exercises change_info_time bump
	cidStMissing = 9550049 // intentionally NOT seeded
)

func setTitleCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9550041 AND 9550049`); err != nil {
		t.Fatalf("setTitleCleanup user_data: %v", err)
	}
}

func TestSetTitle(t *testing.T) {
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

	setTitleCleanup(t, ctx, pool)
	t.Cleanup(func() { setTitleCleanup(t, context.Background(), pool) })

	// Seed user_data with a baseline change_info_time we can compare against.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidStA, "StA"},
		{cidStB, "StB"},
		{cidStNeg, "StNeg"},
		{cidStBump, "StBump"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, cur_title_id, change_info_time)
			 VALUES ($1, $2, $3, 0, 1)`,
			seed.id, seed.name, "st_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("existing char: 1 row affected, payload round-trips, change_info_time bumped", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidStA, int(7777)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var (
			titleID  int
			cit      int64
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cur_title_id, change_info_time FROM user_data WHERE char_id=$1`,
			cidStA).Scan(&titleID, &cit); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if titleID != 7777 {
			t.Fatalf("cur_title_id: got %d, want 7777", titleID)
		}
		// Baseline change_info_time was 1; SP must have bumped it to a real
		// epoch in the multi-billion range (post-2001). Anything > 1_000_000
		// suffices and avoids brittle absolute-time assertions.
		if cit <= 1_000_000 {
			t.Fatalf("change_info_time not bumped: got %d, want > 1_000_000",
				cit)
		}
	})

	t.Run("missing char: 0 rows affected, no error", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidStMissing, int(1234)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			// NCSoft @@ROWCOUNT semantics: 0 = char doesn't exist.
			t.Fatalf("missing: got %d, want 0", affected)
		}
	})

	t.Run("title 0 (no-title sentinel) accepted", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidStB, int(0)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow zero: %v", err)
		}
		if affected != 1 {
			t.Fatalf("zero affected: got %d, want 1", affected)
		}

		var titleID int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cur_title_id FROM user_data WHERE char_id=$1`,
			cidStB).Scan(&titleID); err != nil {
			t.Fatalf("verify zero: %v", err)
		}
		if titleID != 0 {
			t.Fatalf("zero round-trip: got %d, want 0", titleID)
		}
	})

	t.Run("negative title id accepted (GM/dev flag pin)", func(t *testing.T) {
		// Pin: NCSoft signed INT column accepts negatives; observed in
		// dev/test as flag values. We do NOT add a CHECK constraint.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidStNeg, int(-42)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow neg: %v", err)
		}
		if affected != 1 {
			t.Fatalf("neg affected: got %d, want 1", affected)
		}

		var titleID int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cur_title_id FROM user_data WHERE char_id=$1`,
			cidStNeg).Scan(&titleID); err != nil {
			t.Fatalf("verify neg: %v", err)
		}
		if titleID != -42 {
			t.Fatalf("neg round-trip: got %d, want -42", titleID)
		}
	})

	t.Run("re-setting same value still bumps change_info_time", func(t *testing.T) {
		// First call: title 100. Capture cit.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidStBump, int(100)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow bump1: %v", err)
		}
		if affected != 1 {
			t.Fatalf("bump1 affected: got %d, want 1", affected)
		}

		var cit1 int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT change_info_time FROM user_data WHERE char_id=$1`,
			cidStBump).Scan(&cit1); err != nil {
			t.Fatalf("verify cit1: %v", err)
		}

		// Sleep a hair so PG's NOW() advances by at least 1 second
		// (GetUnixtimeWithUTCAdjust uses EXTRACT(EPOCH ...)::BIGINT — second
		// resolution).
		time.Sleep(1100 * time.Millisecond)

		// Second call same value 100. Cache-invalidation contract requires
		// cit to advance regardless of payload-no-op.
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidStBump, int(100)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow bump2: %v", err)
		}
		if affected != 1 {
			t.Fatalf("bump2 affected: got %d, want 1", affected)
		}

		var cit2 int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT change_info_time FROM user_data WHERE char_id=$1`,
			cidStBump).Scan(&cit2); err != nil {
			t.Fatalf("verify cit2: %v", err)
		}
		if cit2 <= cit1 {
			t.Fatalf("change_info_time not bumped on no-op set: cit1=%d cit2=%d, want cit2 > cit1",
				cit1, cit2)
		}
	})
}
