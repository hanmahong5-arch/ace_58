// Package database — integration test for aion_ClearPetitionMsg.
//
// Two-branch eraser paired with 00179 SetPetitionMsg:
//   - same-shard (pet_sv_id == local_sv): UPDATE user_data SET petition_msg=NULL.
//   - cross-shard (pet_sv_id != local_sv): DELETE user_petition_msg row.
//
// Test matrix:
//   - same-shard with live msg: clears to NULL, returns 1
//   - same-shard with already-NULL msg: returns 1 (UPDATE matched the row)
//   - same-shard with no user_data row: returns 0
//   - cross-shard with queued row: deletes it, returns 1
//   - cross-shard with no queued row: returns 0 (nothing to delete)
//   - cross-shard does not affect neighbour char's row at the same sv
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidClearPetMsgLocal     = 9001970 // same-shard live msg target
	cidClearPetMsgLocalNull = 9001971 // same-shard, msg already NULL
	cidClearPetMsgRemote    = 9001972 // cross-shard delete target
	cidClearPetMsgGone      = 9001973 // no user_data row at all
	cidClearPetMsgOther     = 9001974 // neighbour, must not be touched
	localSvClearPetMsg      = 7777
	remoteSvClearPetMsg     = 1111
)

func clearPetitionMsgCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_petition_msg WHERE char_id BETWEEN 9001970 AND 9001979`); err != nil {
		t.Fatalf("clearPetitionMsgCleanup user_petition_msg: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001970 AND 9001979`); err != nil {
		t.Fatalf("clearPetitionMsgCleanup user_data: %v", err)
	}
}

func TestClearPetitionMsg(t *testing.T) {
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

	clearPetitionMsgCleanup(t, ctx, pool)
	t.Cleanup(func() { clearPetitionMsgCleanup(t, context.Background(), pool) })

	// Seed user_data: one with a live msg, one with NULL msg, one neighbour.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, petition_msg)
		 VALUES ($1, 'cpmL',  'cpm_L',  $2),
		        ($3, 'cpmLN', 'cpm_LN', NULL),
		        ($4, 'cpmO',  'cpm_O',  NULL),
		        ($5, 'cpmR',  'cpm_R',  NULL)`,
		cidClearPetMsgLocal, "to-be-cleared",
		cidClearPetMsgLocalNull,
		cidClearPetMsgOther,
		cidClearPetMsgRemote); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	// Cross-shard queued rows: target row + neighbour row at the same sv id.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_petition_msg(char_id, petition_sv_id, msg)
		 VALUES ($1, $2, 'remote-queued'),
		        ($3, $4, 'neighbour-queued')`,
		cidClearPetMsgRemote, remoteSvClearPetMsg,
		cidClearPetMsgOther, remoteSvClearPetMsg); err != nil {
		t.Fatalf("seed user_petition_msg: %v", err)
	}

	t.Run("same-shard clears live msg to NULL", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionmsg",
			cidClearPetMsgLocal, localSvClearPetMsg, localSvClearPetMsg).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("same-shard clear live: got %d, want 1", affected)
		}

		var got *string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT petition_msg FROM user_data WHERE char_id = $1`,
			cidClearPetMsgLocal).Scan(&got); err != nil {
			t.Fatalf("verify NULL: %v", err)
		}
		if got != nil {
			t.Fatalf("after clear: got %q, want NULL", *got)
		}
	})

	t.Run("same-shard with already-NULL msg still returns 1 (row matched)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionmsg",
			cidClearPetMsgLocalNull, localSvClearPetMsg, localSvClearPetMsg).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		// PG UPDATE counts matched rows even when SET makes no value change,
		// so already-NULL → NULL still returns 1. This is the expected
		// T-SQL semantic too (UPDATE counts rows touched, not rows changed).
		if affected != 1 {
			t.Fatalf("same-shard already-null: got %d, want 1", affected)
		}
	})

	t.Run("same-shard with no user_data row returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionmsg",
			cidClearPetMsgGone, localSvClearPetMsg, localSvClearPetMsg).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing user_data: got %d, want 0", affected)
		}
	})

	t.Run("cross-shard deletes the queued row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionmsg",
			cidClearPetMsgRemote, remoteSvClearPetMsg, localSvClearPetMsg).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("cross-shard delete: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_petition_msg WHERE char_id = $1 AND petition_sv_id = $2`,
			cidClearPetMsgRemote, remoteSvClearPetMsg).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 0 {
			t.Fatalf("after delete: got %d rows, want 0", rowCnt)
		}
	})

	t.Run("cross-shard with no queued row returns 0", func(t *testing.T) {
		// cidClearPetMsgRemote+remoteSvClearPetMsg was already deleted above.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_clearpetitionmsg",
			cidClearPetMsgRemote, remoteSvClearPetMsg, localSvClearPetMsg).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("idempotent re-clear: got %d, want 0", affected)
		}
	})

	t.Run("cross-shard delete does NOT touch neighbour at same sv", func(t *testing.T) {
		// Original neighbour row at (cidClearPetMsgOther, remoteSvClearPetMsg)
		// must still be present after all the deletes above.
		var got string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT msg FROM user_petition_msg WHERE char_id = $1 AND petition_sv_id = $2`,
			cidClearPetMsgOther, remoteSvClearPetMsg).Scan(&got); err != nil {
			t.Fatalf("verify neighbour: %v", err)
		}
		if got != "neighbour-queued" {
			t.Fatalf("neighbour leak: got %q, want %q", got, "neighbour-queued")
		}
	})
}
