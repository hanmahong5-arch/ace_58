// Package database — integration test for aion_GetPetitionMsg.
//
// Two-source UNION ALL: row 0 is always the live petition_msg from
// user_data (sv_id echoed from the @nLocalSv parameter), rows 1..N are
// queued cross-shard petitions from user_petition_msg.
//
// Test matrix:
//   - char with live msg + 0 queued                 → 1 row (live, sv echoed)
//   - char with live msg + 2 queued                 → 3 rows (live first, then queued)
//   - char with NULL live msg + 0 queued            → 1 row (live row with empty string, NOT NULL)
//   - char with no user_data row                    → 0 rows (UNION ALL of two empty sets)
//   - neighbour char's queued msgs do NOT leak
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidPetMsgLive   = 9001960 // user_data.petition_msg = "live!", 0 queued
	cidPetMsgFull   = 9001961 // live msg + 2 queued
	cidPetMsgNull   = 9001962 // user_data row exists, petition_msg IS NULL
	cidPetMsgGone   = 9001963 // no user_data row at all
	cidPetMsgOther  = 9001964 // neighbour, queued msgs must NOT leak
	localSvIDA      = 7777    // arbitrary, echoed back as sv_id of live row
)

func getPetitionMsgCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_petition_msg WHERE char_id BETWEEN 9001960 AND 9001969`); err != nil {
		t.Fatalf("getPetitionMsgCleanup user_petition_msg: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001960 AND 9001969`); err != nil {
		t.Fatalf("getPetitionMsgCleanup user_data: %v", err)
	}
}

func TestGetPetitionMsg(t *testing.T) {
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

	getPetitionMsgCleanup(t, ctx, pool)
	t.Cleanup(func() { getPetitionMsgCleanup(t, context.Background(), pool) })

	// Seed user_data with petition_msg payloads (or NULL for cidPetMsgNull).
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id, petition_msg)
		 VALUES ($1, 'pmL', 'pmuL', $2),
		        ($3, 'pmF', 'pmuF', $4),
		        ($5, 'pmN', 'pmuN', NULL),
		        ($6, 'pmO', 'pmuO', NULL)`,
		cidPetMsgLive, "live!",
		cidPetMsgFull, "full-live",
		cidPetMsgNull,
		cidPetMsgOther); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	// Char Full: 2 queued cross-shard petition messages.
	type qRow struct {
		svID int
		msg  string
	}
	queuedFull := []qRow{
		{svID: 1001, msg: "queued-from-shard-1"},
		{svID: 1002, msg: "queued-from-shard-2"},
	}
	for _, q := range queuedFull {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_petition_msg(char_id, petition_sv_id, msg) VALUES ($1, $2, $3)`,
			cidPetMsgFull, q.svID, q.msg); err != nil {
			t.Fatalf("seed queued for Full: %v", err)
		}
	}
	// Neighbour: 1 queued msg that must NOT leak when querying cidPetMsgFull.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_petition_msg(char_id, petition_sv_id, msg) VALUES ($1, $2, $3)`,
		cidPetMsgOther, 9999, "neighbour-queued"); err != nil {
		t.Fatalf("seed queued for Other: %v", err)
	}

	t.Run("live msg with 0 queued returns 1 row with echoed sv_id", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionmsg", cidPetMsgLive, localSvIDA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n            int
			gotSv        int
			gotMsg       string
		)
		for rows.Next() {
			if err := rows.Scan(&gotSv, &gotMsg); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || gotSv != localSvIDA || gotMsg != "live!" {
			t.Fatalf("live-only: n=%d sv=%d msg=%q, want n=1 sv=%d msg=%q",
				n, gotSv, gotMsg, localSvIDA, "live!")
		}
	})

	t.Run("live msg with 2 queued returns 3 rows, live first", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionmsg", cidPetMsgFull, localSvIDA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		type out struct {
			svID int
			msg  string
		}
		var got []out
		for rows.Next() {
			var o out
			if err := rows.Scan(&o.svID, &o.msg); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("full: got %d rows, want 3", len(got))
		}
		// Row 0 is live (UNION ALL left-side priority preserved by PG).
		if got[0].svID != localSvIDA || got[0].msg != "full-live" {
			t.Fatalf("row 0 (live): got sv=%d msg=%q, want sv=%d msg=%q",
				got[0].svID, got[0].msg, localSvIDA, "full-live")
		}
		// Rows 1..2 are queued; sort defensively as PG UNION ALL order beyond
		// left-side guarantee is implementation-dependent for the right side.
		queued := got[1:]
		sort.Slice(queued, func(i, j int) bool { return queued[i].svID < queued[j].svID })
		want := []out{
			{svID: 1001, msg: "queued-from-shard-1"},
			{svID: 1002, msg: "queued-from-shard-2"},
		}
		for i, w := range want {
			if queued[i] != (out(w)) {
				t.Fatalf("queued[%d]: got=%+v, want=%+v", i, queued[i], w)
			}
		}
	})

	t.Run("NULL live msg coalesces to empty string (not NULL)", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionmsg", cidPetMsgNull, localSvIDA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n      int
			gotSv  int
			gotMsg string
		)
		for rows.Next() {
			if err := rows.Scan(&gotSv, &gotMsg); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || gotSv != localSvIDA || gotMsg != "" {
			t.Fatalf("null-live: n=%d sv=%d msg=%q, want n=1 sv=%d msg=\"\"",
				n, gotSv, gotMsg, localSvIDA)
		}
	})

	t.Run("char with no user_data row returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionmsg", cidPetMsgGone, localSvIDA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing user_data: got %d rows, want 0", n)
		}
	})

	t.Run("neighbour's queued msgs do not leak when querying our char", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getpetitionmsg", cidPetMsgFull, localSvIDA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		for rows.Next() {
			var (
				svID int
				msg  string
			)
			if err := rows.Scan(&svID, &msg); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if msg == "neighbour-queued" || svID == 9999 {
				t.Fatalf("neighbour leak: got sv=%d msg=%q in cidPetMsgFull's result",
					svID, msg)
			}
		}
	})
}
