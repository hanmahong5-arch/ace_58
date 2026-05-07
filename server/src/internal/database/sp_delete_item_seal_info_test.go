// Package database — integration test for aion_DeleteItemSealInfo.
//
// DELETE FROM user_item_sealed WHERE id = $1. No char_id guard — caller is
// trusted to authorise. Sister of 00211 SetItemSealInfo / 00212 GetItemSealInfo.
//
// Test matrix:
//   - delete existing id removes the row, returns 1
//   - delete unknown id returns 0 (no error)
//   - re-delete after row is gone returns 0
//   - cross-char delete: any caller with the id can wipe (bug-for-bug pin)
//   - neighbour isolation: deleting one id does not touch sibling ids
//
// char_id band: 9_530_040..9_530_049 (R15 batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidDelSealOwner   = 9530040
	cidDelSealStranger = 9530041 // simulates "any caller with the id can wipe"
	cidDelSealSibling  = 9530042
	itemDelSealMain    = int64(8000020001)
	itemDelSealSibling = int64(8000020002)
	itemDelSealUnknown = int64(8000020999)
)

func deleteItemSealInfoCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item_sealed WHERE id BETWEEN 8000020001 AND 8000020999`); err != nil {
		t.Fatalf("deleteItemSealInfoCleanup user_item_sealed: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9530040 AND 9530049`); err != nil {
		t.Fatalf("deleteItemSealInfoCleanup user_data: %v", err)
	}
}

func TestDeleteItemSealInfo(t *testing.T) {
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

	deleteItemSealInfoCleanup(t, ctx, pool)
	t.Cleanup(func() { deleteItemSealInfoCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidDelSealOwner, "DelOwner"},
		{cidDelSealStranger, "DelStranger"},
		{cidDelSealSibling, "DelSibling"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "del_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Seed a seal owned by cidDelSealOwner, plus a sibling seal owned by
	// cidDelSealSibling that must remain untouched after the main delete.
	if err := pool.CallSPExec(ctx, "aion_setitemsealinfo",
		cidDelSealOwner, itemDelSealMain, int(1), int(1700000000)); err != nil {
		t.Fatalf("seed main: %v", err)
	}
	if err := pool.CallSPExec(ctx, "aion_setitemsealinfo",
		cidDelSealSibling, itemDelSealSibling, int(1), int(1700000111)); err != nil {
		t.Fatalf("seed sibling: %v", err)
	}

	t.Run("delete unknown id returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteitemsealinfo", itemDelSealUnknown).
			Scan(&affected); err != nil {
			t.Fatalf("CallSPRow unknown: %v", err)
		}
		if affected != 0 {
			t.Fatalf("unknown id: got %d, want 0", affected)
		}
	})

	t.Run("cross-char delete succeeds — any caller with id can wipe", func(t *testing.T) {
		// Bug-for-bug pin: SP takes only item_id; no char_id authorisation.
		// We simulate "stranger" deletion by simply calling with the id —
		// the SP has no notion of the caller. The point is that the row
		// owned by cidDelSealOwner gets wiped without any cross-check.
		_ = cidDelSealStranger // referenced to make the intent obvious
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteitemsealinfo", itemDelSealMain).
			Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("delete main: got %d, want 1", affected)
		}

		// Row gone.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_item_sealed WHERE id = $1`,
			itemDelSealMain).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("row not deleted: cnt=%d", cnt)
		}
	})

	t.Run("re-delete after row is gone returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_deleteitemsealinfo", itemDelSealMain).
			Scan(&affected); err != nil {
			t.Fatalf("CallSPRow re-delete: %v", err)
		}
		if affected != 0 {
			t.Fatalf("re-delete: got %d, want 0", affected)
		}
	})

	t.Run("neighbour isolation: sibling row untouched", func(t *testing.T) {
		// Delete by id is keyed on the PK only; deleting itemDelSealMain must
		// NOT have touched itemDelSealSibling. Verify it still exists with its
		// payload intact.
		var (
			seal, expired int
			ownedBy       int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT "sealState", "sealExpiredTime", char_id
			   FROM user_item_sealed WHERE id = $1`, itemDelSealSibling).
			Scan(&seal, &expired, &ownedBy); err != nil {
			t.Fatalf("verify sibling: %v", err)
		}
		if seal != 1 || expired != 1700000111 || ownedBy != cidDelSealSibling {
			t.Fatalf("sibling collateral damage: state=%d expired=%d owner=%d",
				seal, expired, ownedBy)
		}
	})
}
