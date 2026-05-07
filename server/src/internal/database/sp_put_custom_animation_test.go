// Package database — integration test for aion_PutCustomAnimation.
//
// Three-statement contract:
//   (1) clear use_state on any other rows of the same animation_type
//   (2) try to update target row (sets type+expire+use_state=1)
//   (3) if target absent, insert fresh row with use_state=1
//
// Test matrix:
//   - first put: target absent → INSERT path, use_state=1, expire matches
//   - re-equip same id: row update, use_state stays 1, expire refreshed
//   - swap within same type: equipping anim_id=B clears anim_id=A's use_state
//     (this is the classic NCSoft "one-equipped-per-type" invariant)
//   - distinct types untouched: equip type=1 doesn't perturb a type=2 row
//   - neighbour isolation: A's equip doesn't perturb B's same-type row
//   - rebind expire: pure expire-time refresh on already-equipped target
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidCAnimA = 9490001
	cidCAnimB = 9490002
)

func putCustomAnimationCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_custom_animation WHERE char_id BETWEEN 9490001 AND 9490099`); err != nil {
		t.Fatalf("putCustomAnimationCleanup user_custom_animation: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9490001 AND 9490099`); err != nil {
		t.Fatalf("putCustomAnimationCleanup user_data: %v", err)
	}
}

func TestPutCustomAnimation(t *testing.T) {
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

	putCustomAnimationCleanup(t, ctx, pool)
	t.Cleanup(func() { putCustomAnimationCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidCAnimA, "AnimA"},
		{cidCAnimB, "AnimB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "ca_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("first put: INSERT path, use_state=1, expire matches", func(t *testing.T) {
		var (
			animID   int32 = 1001
			animType int16 = 1
			expire   int64 = 1_700_001_000
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putcustomanimation",
			cidCAnimA, animID, animType, expire).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first: got %d, want 1", affected)
		}

		var (
			gotType   int16
			gotExpire int64
			gotState  int16
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT animation_type, expire_time, use_state
			   FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = $2`,
			cidCAnimA, animID).Scan(&gotType, &gotExpire, &gotState); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if gotType != animType || gotExpire != expire || gotState != 1 {
			t.Fatalf("first state: type=%d expire=%d use_state=%d",
				gotType, gotExpire, gotState)
		}
	})

	t.Run("re-equip same id: UPDATE path, expire refreshed, use_state still 1", func(t *testing.T) {
		const animID int32 = 1001
		const animType int16 = 1
		const newExpire int64 = 1_800_002_000
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putcustomanimation",
			cidCAnimA, animID, animType, newExpire).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow re-equip: %v", err)
		}
		if affected != 1 {
			t.Fatalf("re-equip: got %d, want 1", affected)
		}

		var (
			gotExpire int64
			gotState  int16
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expire_time, use_state FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = $2`,
			cidCAnimA, animID).Scan(&gotExpire, &gotState); err != nil {
			t.Fatalf("verify re-equip: %v", err)
		}
		if gotExpire != newExpire || gotState != 1 {
			t.Fatalf("re-equip state: expire=%d use_state=%d", gotExpire, gotState)
		}

		// Still exactly 1 row for this (char, anim_id) pair.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = $2`,
			cidCAnimA, animID).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("re-equip cnt: got %d, want 1", cnt)
		}
	})

	t.Run("swap within same type: equip B clears A's use_state", func(t *testing.T) {
		// 1001 (type=1) is already equipped from above. Equip 1002 (type=1).
		const newID int32 = 1002
		const animType int16 = 1
		const expire int64 = 1_750_000_000
		if err := pool.CallSPExec(ctx, "aion_putcustomanimation",
			cidCAnimA, newID, animType, expire); err != nil {
			t.Fatalf("CallSPExec swap: %v", err)
		}

		// 1001's use_state must now be 0.
		var oldState int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_state FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = 1001`,
			cidCAnimA).Scan(&oldState); err != nil {
			t.Fatalf("verify 1001 state: %v", err)
		}
		if oldState != 0 {
			t.Fatalf("1001 use_state: got %d, want 0 (swap-out)", oldState)
		}

		// 1002 should be use_state=1.
		var newState int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_state FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = $2`,
			cidCAnimA, newID).Scan(&newState); err != nil {
			t.Fatalf("verify 1002 state: %v", err)
		}
		if newState != 1 {
			t.Fatalf("1002 use_state: got %d, want 1 (newly-equipped)", newState)
		}
	})

	t.Run("distinct types untouched: equip type=2 leaves type=1 equipped", func(t *testing.T) {
		// 1002 currently equipped (type=1). Add a type=2 anim.
		const tType2ID int32 = 2001
		const tType2 int16 = 2
		if err := pool.CallSPExec(ctx, "aion_putcustomanimation",
			cidCAnimA, tType2ID, tType2, int64(1_900_000_000)); err != nil {
			t.Fatalf("CallSPExec type2: %v", err)
		}

		// 1002 (type=1) should remain use_state=1.
		var stateT1 int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_state FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = 1002`,
			cidCAnimA).Scan(&stateT1); err != nil {
			t.Fatalf("verify 1002 type1: %v", err)
		}
		if stateT1 != 1 {
			t.Fatalf("1002 type=1 perturbed by type=2: got use_state=%d, want 1", stateT1)
		}

		// 2001 (type=2) should be use_state=1.
		var stateT2 int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_state FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = $2`,
			cidCAnimA, tType2ID).Scan(&stateT2); err != nil {
			t.Fatalf("verify 2001 type2: %v", err)
		}
		if stateT2 != 1 {
			t.Fatalf("2001 use_state: got %d, want 1", stateT2)
		}
	})

	t.Run("neighbour isolation: A's swap doesn't perturb B's same-type row", func(t *testing.T) {
		// Seed B with a type=1 anim, equipped.
		const bID int32 = 1077
		const bType int16 = 1
		if err := pool.CallSPExec(ctx, "aion_putcustomanimation",
			cidCAnimB, bID, bType, int64(1_500_000_000)); err != nil {
			t.Fatalf("CallSPExec B seed: %v", err)
		}

		// Now A equips a brand-new type=1 anim. Must NOT clear B's row.
		const aNewID int32 = 1003
		if err := pool.CallSPExec(ctx, "aion_putcustomanimation",
			cidCAnimA, aNewID, bType, int64(1_600_000_000)); err != nil {
			t.Fatalf("CallSPExec A new: %v", err)
		}

		var bState int16
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_state FROM user_custom_animation
			  WHERE char_id = $1 AND animation_id = $2`,
			cidCAnimB, bID).Scan(&bState); err != nil {
			t.Fatalf("verify B intact: %v", err)
		}
		if bState != 1 {
			t.Fatalf("B leaked from A: got use_state=%d, want 1", bState)
		}
	})
}
