// Package database — integration test for the house_bidding SP pair
// (00259 GetAuctionBettingList / 00260 DeleteAuctionBetting), with a
// cross-SP pin against the previously-ported 00071 SetAuctionBetting.
//
// Domain (`house_bidding`, batch 25):
//   user_betting is the at-most-one-bet-per-character ledger backing the
//   housing-auction UI. Three SPs cover the full lifecycle:
//     * 00071 setAuctionBetting  → UPSERT (already ported)
//     * 00259 GetAuctionBettingList → SELECT-all (this batch)
//     * 00260 deleteAuctionBetting  → DELETE one (this batch)
//
// Test matrix:
//   - GetAuctionBettingList on empty band → 0 rows in band
//   - SetAuctionBetting populates a row → Get surfaces it round-trip
//   - DeleteAuctionBetting on existing row → returns 1, row gone
//   - DeleteAuctionBetting on missing row → returns 0, no error
//   - Re-Set after Delete → row returns; Get reflects new auction/qina
//   - Multiple bidders coexist; Delete is scoped to one ownerid
//
// char_id band: 9_650_001..9_650_039 (R25 betting subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAbA   = 9650001 // basic Set → Get round-trip + Delete
	cidAbB   = 9650002 // sibling row, must survive delete of cidAbA
	cidAbC   = 9650003 // monotonic Set after Delete
	cidAbGap = 9650099 // a char_id with no row — exercises 0-affected DELETE
)

func auctionBettingListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	// user_betting is char-keyed via ownerid PK — wipe by band.
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_betting WHERE ownerid BETWEEN 9650001 AND 9650099`); err != nil {
		t.Fatalf("auctionBettingListCleanup: %v", err)
	}
}

// countBettingInBand returns the count of user_betting rows in the test
// char_id band — Get is full-table, so we must scope test assertions to
// the band to remain hermetic against parallel SPs that might insert
// outside it.
func countBettingInBand(t *testing.T, ctx context.Context, p *Pool) int {
	t.Helper()
	var n int
	if err := p.Inner().QueryRow(ctx,
		`SELECT COUNT(*) FROM user_betting WHERE ownerid BETWEEN 9650001 AND 9650099`).
		Scan(&n); err != nil {
		t.Fatalf("countBettingInBand: %v", err)
	}
	return n
}

func TestAuctionBettingList(t *testing.T) {
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

	auctionBettingListCleanup(t, ctx, pool)
	t.Cleanup(func() { auctionBettingListCleanup(t, context.Background(), pool) })

	t.Run("Get on empty band yields no rows in band", func(t *testing.T) {
		// Other tests may seed user_betting outside our band; the SP returns
		// the full table. We assert hermetic emptiness via band-scoped count.
		if got := countBettingInBand(t, ctx, pool); got != 0 {
			t.Fatalf("pre-condition: want 0 rows in band, got %d", got)
		}

		// Exercise the SP itself — the result set may be non-empty (other
		// tests' data) but must not error. Iterate to drain.
		rows, err := pool.CallSP(ctx, "aion_getauctionbettinglist")
		if err != nil {
			t.Fatalf("CallSP empty: %v", err)
		}
		defer rows.Close()
		for rows.Next() {
			var (
				owner   int
				auction int64
				qina    int64
			)
			if err := rows.Scan(&owner, &auction, &qina); err != nil {
				t.Fatalf("rows.Scan empty: %v", err)
			}
			// Foreign rows from other tests are tolerated — only band rows
			// are part of our hermetic contract.
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("rows.Err empty: %v", err)
		}
	})

	t.Run("Set→Get round-trips payload", func(t *testing.T) {
		// Seed via 00071.
		var ack int
		if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
			int(cidAbA), int64(700001), int64(50000)).Scan(&ack); err != nil {
			t.Fatalf("seed Set cidAbA: %v", err)
		}
		if ack != cidAbA {
			t.Fatalf("seed ack: got %d want %d", ack, cidAbA)
		}

		// Get and find our row.
		rows, err := pool.CallSP(ctx, "aion_getauctionbettinglist")
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		var found bool
		var (
			gotOwner   int
			gotAuction int64
			gotQina    int64
		)
		for rows.Next() {
			var (
				owner   int
				auction int64
				qina    int64
			)
			if err := rows.Scan(&owner, &auction, &qina); err != nil {
				t.Fatalf("rows.Scan: %v", err)
			}
			if owner == cidAbA {
				found = true
				gotOwner, gotAuction, gotQina = owner, auction, qina
			}
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("rows.Err: %v", err)
		}
		if !found {
			t.Fatalf("Get did not surface seeded row for ownerid=%d", cidAbA)
		}
		if gotOwner != cidAbA || gotAuction != 700001 || gotQina != 50000 {
			t.Fatalf("payload: owner=%d auction=%d qina=%d, want %d/700001/50000",
				gotOwner, gotAuction, gotQina, cidAbA)
		}
	})

	t.Run("Delete on existing row → 1 affected, row gone", func(t *testing.T) {
		// Seed sibling first so we can prove Delete is scoped.
		if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
			int(cidAbB), int64(700002), int64(60000)).Scan(new(int)); err != nil {
			t.Fatalf("seed Set cidAbB: %v", err)
		}

		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionbetting",
			int(cidAbA)).Scan(&affected); err != nil {
			t.Fatalf("Delete cidAbA: %v", err)
		}
		if affected != 1 {
			t.Fatalf("Delete cidAbA affected: got %d want 1", affected)
		}

		// Verify the target row is gone but the sibling survives.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_betting WHERE ownerid=$1`, cidAbA).
			Scan(&n); err != nil {
			t.Fatalf("verify gone: %v", err)
		}
		if n != 0 {
			t.Fatalf("post-delete row count for cidAbA: got %d want 0", n)
		}

		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_betting WHERE ownerid=$1`, cidAbB).
			Scan(&n); err != nil {
			t.Fatalf("verify sibling: %v", err)
		}
		if n != 1 {
			t.Fatalf("sibling row count: got %d want 1 (must survive scoped delete)", n)
		}
	})

	t.Run("Delete on missing row → 0 affected, no error", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionbetting",
			int(cidAbGap)).Scan(&affected); err != nil {
			t.Fatalf("Delete missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("Delete missing affected: got %d want 0", affected)
		}
	})

	t.Run("Re-Set after Delete reinserts; Get reflects new payload", func(t *testing.T) {
		// Insert.
		if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
			int(cidAbC), int64(700003), int64(70000)).Scan(new(int)); err != nil {
			t.Fatalf("seed initial: %v", err)
		}
		// Delete.
		if err := pool.CallSPRow(ctx, "aion_deleteauctionbetting",
			int(cidAbC)).Scan(new(int)); err != nil {
			t.Fatalf("Delete: %v", err)
		}
		// Re-Set with NEW payload.
		if err := pool.CallSPRow(ctx, "aion_setauctionbetting",
			int(cidAbC), int64(700099), int64(99999)).Scan(new(int)); err != nil {
			t.Fatalf("re-Set: %v", err)
		}

		// Verify via direct read that the row exists with new payload.
		var (
			auction int64
			qina    int64
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT auctionid, qina FROM user_betting WHERE ownerid=$1`, cidAbC).
			Scan(&auction, &qina); err != nil {
			t.Fatalf("verify re-Set: %v", err)
		}
		if auction != 700099 || qina != 99999 {
			t.Fatalf("re-Set payload: auction=%d qina=%d, want 700099/99999",
				auction, qina)
		}
	})
}
