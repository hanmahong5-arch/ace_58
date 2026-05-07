// Package database — integration test for aion_DeleteAuctionFilterList.
//
// Pure DELETE on user_auctionfilter scoped by (type, goodsID). Returns
// rows-affected (NCSoft @@ROWCOUNT pin): 0 means no matching row, 1 means
// removed. Asymmetric with Add (00224 EXISTS guards on goodsID alone) —
// Delete needs the exact (type, goodsID) pair.
//
// Test matrix:
//   - delete existing (type, goodsID) → 1 row, row gone
//   - delete with wrong type leaves filter in place (silent 0)
//   - delete non-existent goodsID returns 0
//
// goodsID band: 95_60_021..95_60_039 (R18 batch — delete subset).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	goodsDfA       = 95600121 // exists, deleted with right type
	goodsDfWrongTy = 95600122 // exercises wrong-type-silent pin
	goodsDfMissing = 95600139 // never seeded
)

func deleteAuctionFilterCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_auctionfilter WHERE goodsID BETWEEN 95600121 AND 95600139`); err != nil {
		t.Fatalf("deleteAuctionFilterCleanup: %v", err)
	}
}

func TestDeleteAuctionFilterList(t *testing.T) {
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

	deleteAuctionFilterCleanup(t, ctx, pool)
	t.Cleanup(func() { deleteAuctionFilterCleanup(t, context.Background(), pool) })

	// Seed two filter rows under known (type, goodsID).
	for _, seed := range []struct {
		typ   int
		goods int
	}{
		{3, goodsDfA},
		{4, goodsDfWrongTy},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_auctionfilter(type, goodsID) VALUES ($1, $2)`,
			seed.typ, seed.goods); err != nil {
			t.Fatalf("seed (type=%d goodsID=%d): %v", seed.typ, seed.goods, err)
		}
	}

	t.Run("delete existing (type, goodsID) returns 1, row gone", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionfilterlist",
			int(3), int(goodsDfA)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("affected: got %d, want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_auctionfilter WHERE goodsID=$1`,
			goodsDfA).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("after delete: got %d rows, want 0", n)
		}
	})

	t.Run("delete with wrong type leaves row in place (silent 0)", func(t *testing.T) {
		// goodsDfWrongTy was seeded with type=4. Calling delete with type=99
		// must NOT touch the row, NOT raise an error.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionfilterlist",
			int(99), int(goodsDfWrongTy)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow wrong-type: %v", err)
		}
		if affected != 0 {
			t.Fatalf("wrong-type affected: got %d, want 0", affected)
		}

		// Confirm row still exists with the original type=4.
		var (
			n     int
			gType int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*), MAX(type) FROM user_auctionfilter WHERE goodsID=$1`,
			goodsDfWrongTy).Scan(&n, &gType); err != nil {
			t.Fatalf("verify wrong-type: %v", err)
		}
		if n != 1 || gType != 4 {
			t.Fatalf("wrong-type leftover: got n=%d type=%d, want n=1 type=4", n, gType)
		}
	})

	t.Run("delete non-existent goodsID returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteauctionfilterlist",
			int(1), int(goodsDfMissing)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing affected: got %d, want 0", affected)
		}
	})
}
