// Package database — integration test for aion_SetPetitionMsg.
//
// Two-branch writer paired with 00178 GetPetitionMsg:
//   - same-shard (pet_sv_id == local_sv): UPDATE user_data.petition_msg.
//   - cross-shard (pet_sv_id != local_sv): UPSERT user_petition_msg.
//
// Test matrix:
//   - same-shard insert-then-update: live msg overwrites in place
//   - same-shard with no user_data row: returns 0 (no-op)
//   - cross-shard first call: inserts row, returns 1
//   - cross-shard second call same (char, sv): updates in place, no duplicate
//   - cross-shard different sv on same char: separate row
//   - neighbour char's queued rows do NOT collide on upsert
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidSetPetMsgLocal    = 9001965 // same-shard live msg target
	cidSetPetMsgRemote   = 9001966 // cross-shard upsert target
	cidSetPetMsgGone     = 9001967 // no user_data row at all
	cidSetPetMsgOther    = 9001968 // neighbour, must not collide
	localSvSetPetMsg     = 7777    // local sv id; pet_sv == this → same-shard branch
	remoteSvSetPetMsgA   = 1111    // a cross-shard sv id
	remoteSvSetPetMsgB   = 2222    // a second cross-shard sv id
)

func setPetitionMsgCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_petition_msg WHERE char_id BETWEEN 9001965 AND 9001969`); err != nil {
		t.Fatalf("setPetitionMsgCleanup user_petition_msg: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001965 AND 9001969`); err != nil {
		t.Fatalf("setPetitionMsgCleanup user_data: %v", err)
	}
}

func TestSetPetitionMsg(t *testing.T) {
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

	setPetitionMsgCleanup(t, ctx, pool)
	t.Cleanup(func() { setPetitionMsgCleanup(t, context.Background(), pool) })

	// Seed user_data rows for the chars that need a same-shard target.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidSetPetMsgLocal, "spmL"},
		{cidSetPetMsgRemote, "spmR"},
		{cidSetPetMsgOther, "spmO"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "spm_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	t.Run("same-shard first call writes live msg", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgLocal, localSvSetPetMsg, localSvSetPetMsg,
			"hello-live-1").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("same-shard first: got %d, want 1", affected)
		}

		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT petition_msg FROM user_data WHERE char_id = $1`,
			cidSetPetMsgLocal).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != "hello-live-1" {
			t.Fatalf("live msg: got %q, want %q", got, "hello-live-1")
		}
	})

	t.Run("same-shard second call overwrites in place", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgLocal, localSvSetPetMsg, localSvSetPetMsg,
			"hello-live-2").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("same-shard overwrite: got %d, want 1", affected)
		}

		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT petition_msg FROM user_data WHERE char_id = $1`,
			cidSetPetMsgLocal).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != "hello-live-2" {
			t.Fatalf("overwrite: got %q, want %q", got, "hello-live-2")
		}
	})

	t.Run("same-shard with no user_data row returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgGone, localSvSetPetMsg, localSvSetPetMsg,
			"will-not-land").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing user_data: got %d, want 0", affected)
		}
	})

	t.Run("cross-shard first call inserts queued row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgRemote, remoteSvSetPetMsgA, localSvSetPetMsg,
			"queued-A-v1").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("cross-shard first: got %d, want 1", affected)
		}

		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT msg FROM user_petition_msg WHERE char_id = $1 AND petition_sv_id = $2`,
			cidSetPetMsgRemote, remoteSvSetPetMsgA).Scan(&got); err != nil {
			t.Fatalf("verify queued: %v", err)
		}
		if got != "queued-A-v1" {
			t.Fatalf("queued msg: got %q, want %q", got, "queued-A-v1")
		}
	})

	t.Run("cross-shard second call same (char, sv) updates in place", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgRemote, remoteSvSetPetMsgA, localSvSetPetMsg,
			"queued-A-v2").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("cross-shard upsert: got %d, want 1", affected)
		}

		// Single row only — no duplicate inserted.
		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_msg WHERE char_id = $1 AND petition_sv_id = $2`,
			cidSetPetMsgRemote, remoteSvSetPetMsgA).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after upsert: got %d, want 1", rowCnt)
		}

		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT msg FROM user_petition_msg WHERE char_id = $1 AND petition_sv_id = $2`,
			cidSetPetMsgRemote, remoteSvSetPetMsgA).Scan(&got); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if got != "queued-A-v2" {
			t.Fatalf("upserted msg: got %q, want %q", got, "queued-A-v2")
		}
	})

	t.Run("cross-shard different sv on same char inserts separate row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgRemote, remoteSvSetPetMsgB, localSvSetPetMsg,
			"queued-B").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second sv: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_msg WHERE char_id = $1`,
			cidSetPetMsgRemote).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 2 {
			t.Fatalf("rows for char Remote: got %d, want 2 (sv A + sv B)", rowCnt)
		}
	})

	t.Run("neighbour char does not collide on cross-shard upsert", func(t *testing.T) {
		// Same sv id as cidSetPetMsgRemote's row, different char — must NOT
		// collide; UNIQUE index is (char_id, petition_sv_id) composite.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setpetitionmsg",
			cidSetPetMsgOther, remoteSvSetPetMsgA, localSvSetPetMsg,
			"neighbour-msg").Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("neighbour insert: got %d, want 1", affected)
		}

		// Original char's row still has its v2 payload, unchanged.
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT msg FROM user_petition_msg WHERE char_id = $1 AND petition_sv_id = $2`,
			cidSetPetMsgRemote, remoteSvSetPetMsgA).Scan(&got); err != nil {
			t.Fatalf("verify Remote untouched: %v", err)
		}
		if got != "queued-A-v2" {
			t.Fatalf("Remote leak: got %q, want %q", got, "queued-A-v2")
		}
	})
}
