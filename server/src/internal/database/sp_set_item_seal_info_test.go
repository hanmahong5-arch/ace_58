// Package database — integration test for aion_SetItemSealInfo.
//
// UPSERT on user_item_sealed PK(id). Seals the user_item.id surrogate with
// (sealState, sealExpiredTime, char_id). char_id is OVERWRITTEN on UPDATE —
// NCSoft's "last-toucher wins" model for seal ownership transfer.
//
// Test matrix:
//   - first call inserts 1 row, all 4 columns round-trip
//   - second call same id updates all 3 mutable cols (sealState, expired, char_id)
//   - char_id ownership transfers on UPDATE (bug-for-bug pin)
//   - distinct ids coexist (no collision)
//   - missing user_data: SetItemSealInfo still succeeds (no FK)
//
// char_id band: 9_530_020..9_530_029 (R15 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidSetSealOwner    = 9530020 // first owner
	cidSetSealNewOwner = 9530021 // takes over via re-set
	cidSetSealMissing  = 9530029 // no user_data row (orphan-set canary)
	itemSetSealA       = int64(8000000001)
	itemSetSealB       = int64(8000000002)
	itemSetSealOrphan  = int64(8000000099)
)

func setItemSealInfoCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_sealed WHERE id BETWEEN 8000000001 AND 8000000099`); err != nil {
		t.Fatalf("setItemSealInfoCleanup user_item_sealed: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9530020 AND 9530029`); err != nil {
		t.Fatalf("setItemSealInfoCleanup user_data: %v", err)
	}
}

func TestSetItemSealInfo(t *testing.T) {
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

	setItemSealInfoCleanup(t, ctx, pool)
	t.Cleanup(func() { setItemSealInfoCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidSetSealOwner, "SealOwner"},
		{cidSetSealNewOwner, "SealNewOwner"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "seal_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first call inserts 1 row, full round-trip", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setitemsealinfo",
			cidSetSealOwner, itemSetSealA, int(1), int(1700000000),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow first: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first: got %d, want 1", affected)
		}

		// PG quotes the PascalCase columns; we mirror that in the verify SELECT.
		var (
			seal, expired int
			ownedBy       int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT "sealState", "sealExpiredTime", char_id
			   FROM user_item_sealed WHERE id = $1`, itemSetSealA).
			Scan(&seal, &expired, &ownedBy); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if seal != 1 || expired != 1700000000 || ownedBy != cidSetSealOwner {
			t.Fatalf("round-trip: state=%d expired=%d owner=%d, want 1/1700000000/%d",
				seal, expired, ownedBy, cidSetSealOwner)
		}
	})

	t.Run("second call same id updates state + expired + char_id", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setitemsealinfo",
			cidSetSealNewOwner, itemSetSealA, int(2), int(1800000000),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow update: %v", err)
		}
		if affected != 1 {
			t.Fatalf("update affected: got %d, want 1", affected)
		}

		// Single row only.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_sealed WHERE id = $1`,
			itemSetSealA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rows after upsert: got %d, want 1", cnt)
		}

		var (
			seal, expired int
			ownedBy       int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT "sealState", "sealExpiredTime", char_id
			   FROM user_item_sealed WHERE id = $1`, itemSetSealA).
			Scan(&seal, &expired, &ownedBy); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if seal != 2 || expired != 1800000000 {
			t.Fatalf("update payload: state=%d expired=%d, want 2/1800000000", seal, expired)
		}
		// CRITICAL: char_id transferred to the new caller (last-toucher wins).
		if ownedBy != cidSetSealNewOwner {
			t.Fatalf("ownership transfer broken: owner=%d, want %d (last-toucher wins)",
				ownedBy, cidSetSealNewOwner)
		}
	})

	t.Run("distinct ids coexist", func(t *testing.T) {
		// Add itemSetSealB under cidSetSealOwner — must not collide with itemA.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setitemsealinfo",
			cidSetSealOwner, itemSetSealB, int(0), int(0),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow B: %v", err)
		}
		if affected != 1 {
			t.Fatalf("B insert: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_sealed
			  WHERE id IN ($1, $2)`, itemSetSealA, itemSetSealB).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 2 {
			t.Fatalf("two ids: got %d rows, want 2", cnt)
		}
	})

	t.Run("missing user_data: SetItemSealInfo still succeeds (no FK)", func(t *testing.T) {
		// Bug-for-bug: NCSoft user_item_sealed has no FK on char_id. We can
		// pin a seal on a char that does not exist in user_data.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setitemsealinfo",
			cidSetSealMissing, itemSetSealOrphan, int(1), int(1900000000),
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow orphan: %v", err)
		}
		if affected != 1 {
			t.Fatalf("orphan: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_sealed WHERE id = $1`,
			itemSetSealOrphan).Scan(&cnt); err != nil {
			t.Fatalf("count orphan: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("orphan cnt: got %d, want 1", cnt)
		}
	})
}
