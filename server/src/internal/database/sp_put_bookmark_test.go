// Package database — integration test for aion_PutBookmark.
//
// Plain INSERT (no UPSERT). PK is (char_id, bookmark_slot); slot reuse raises
// 23505 unique_violation — bug-for-bug NCSoft. Caller must DELETE the slot
// first if reusing.
//
// Test matrix:
//   - happy path: first put inserts 1 row, all 6 fields persist
//   - distinct slots coexist: 3 puts on same char with different slots → 3 rows
//   - duplicate slot: 2nd put on same (char, slot) raises a unique_violation
//   - neighbour isolation: same slot index on different chars → both succeed
//   - bookmark_name preserved verbatim (UTF-8 wide chars + edge punctuation)
package database

import (
	"context"
	"strings"
	"testing"
	"time"
)

const (
	cidBookmarkA = 9460001
	cidBookmarkB = 9460002
)

func putBookmarkCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM bookmark WHERE char_id BETWEEN 9460001 AND 9460099`); err != nil {
		t.Fatalf("putBookmarkCleanup bookmark: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9460001 AND 9460099`); err != nil {
		t.Fatalf("putBookmarkCleanup user_data: %v", err)
	}
}

func TestPutBookmark(t *testing.T) {
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

	putBookmarkCleanup(t, ctx, pool)
	t.Cleanup(func() { putBookmarkCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidBookmarkA, "BmCharA"},
		{cidBookmarkB, "BmCharB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "bm_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: first put inserts 1 row, all 6 fields match", func(t *testing.T) {
		var (
			slot  int16   = 0
			name          = "Sanctum"
			world int32   = 210010000
			x     float32 = 1500.5
			y     float32 = 2500.25
			z     float32 = 100.125
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putbookmark",
			cidBookmarkA, slot, name, world, x, y, z).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var (
			gotSlot  int16
			gotName  string
			gotWorld int32
			gotX     float32
			gotY     float32
			gotZ     float32
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT bookmark, bookmark_name, world, x, y, z FROM bookmark
			  WHERE char_id = $1`, cidBookmarkA).Scan(
			&gotSlot, &gotName, &gotWorld, &gotX, &gotY, &gotZ); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if gotSlot != slot || gotName != name || gotWorld != world ||
			gotX != x || gotY != y || gotZ != z {
			t.Fatalf("happy fields: got slot=%d name=%q world=%d xyz=%g/%g/%g",
				gotSlot, gotName, gotWorld, gotX, gotY, gotZ)
		}
	})

	t.Run("distinct slots coexist: 3 puts on same char → 3 rows", func(t *testing.T) {
		// Slot 0 is taken from happy. Add 1 and 2.
		for _, slot := range []int16{1, 2} {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putbookmark",
				cidBookmarkA, slot, "Slot"+string(rune('0'+slot)),
				int32(210020000+int(slot)), float32(slot)*100.0,
				float32(slot)*200.0, float32(slot)*50.0).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow slot=%d: %v", slot, err)
			}
			if affected != 1 {
				t.Fatalf("slot %d: got %d, want 1", slot, affected)
			}
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM bookmark WHERE char_id = $1`,
			cidBookmarkA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 3 {
			t.Fatalf("3 distinct slots: got %d, want 3", cnt)
		}
	})

	t.Run("duplicate slot: 2nd put raises unique_violation (bug-for-bug)", func(t *testing.T) {
		// Slot 0 is occupied. A second put on the same slot must error.
		// CallSPRow returns a pgx.Row whose Scan() surfaces the error; we
		// expect a 23505 unique violation, not a clean 0.
		err := pool.CallSPRow(ctx, "aion_putbookmark",
			cidBookmarkA, int16(0), "Replacement",
			int32(0), float32(0), float32(0), float32(0)).Scan(new(int))
		if err == nil {
			t.Fatalf("dup slot: expected unique_violation, got nil")
		}
		if !strings.Contains(err.Error(), "duplicate key") &&
			!strings.Contains(err.Error(), "23505") &&
			!strings.Contains(err.Error(), "unique") {
			t.Fatalf("dup slot: expected unique_violation pgerror, got %v", err)
		}
	})

	t.Run("neighbour isolation: slot 0 on B succeeds independently of A", func(t *testing.T) {
		// Same slot 0 but different char_id: PK is (char_id, slot), so allowed.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putbookmark",
			cidBookmarkB, int16(0), "BSlot0",
			int32(210099999), float32(9999), float32(9999), float32(9999)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B slot0: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B slot0: got %d, want 1", affected)
		}

		// A's slot 0 must still be the original "Sanctum", not "BSlot0".
		var aName string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT bookmark_name FROM bookmark WHERE char_id = $1 AND bookmark = 0`,
			cidBookmarkA).Scan(&aName); err != nil {
			t.Fatalf("verify A intact: %v", err)
		}
		if aName != "Sanctum" {
			t.Fatalf("A slot0 leaked from B: got %q, want %q", aName, "Sanctum")
		}
	})

	t.Run("bookmark_name preserved verbatim (UTF-8 wide chars)", func(t *testing.T) {
		// 5.8 client labels often contain Korean/Chinese chars + punctuation.
		// PG TEXT must round-trip them byte-perfectly.
		const wideName = "晓光・神域★A"
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putbookmark",
			cidBookmarkB, int16(1), wideName,
			int32(210030000), float32(0), float32(0), float32(0)).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow wide: %v", err)
		}
		if affected != 1 {
			t.Fatalf("wide: got %d, want 1", affected)
		}

		var gotName string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT bookmark_name FROM bookmark WHERE char_id = $1 AND bookmark = 1`,
			cidBookmarkB).Scan(&gotName); err != nil {
			t.Fatalf("verify wide: %v", err)
		}
		if gotName != wideName {
			t.Fatalf("wide name: got %q, want %q", gotName, wideName)
		}
	})
}
