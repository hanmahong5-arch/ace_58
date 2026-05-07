// Package database — integration test for aion_PutGuildHistory.
//
// Pure INSERT into guild_history (append-only audit log). No UNIQUE on any
// column — multiple events at the same timestamp are allowed and expected.
//
// Test matrix:
//   - first put inserts 1 row, returns 1
//   - 5 puts on same guild_id → 5 rows in chronological order
//   - duplicate put (same eventDate + eventType + params) ALSO inserts (no UNIQUE)
//   - neighbour isolation: putting on guild A doesn't pollute guild B's tail
//   - history persists past guild deletion (no FK — forensic survival)
package database

import (
	"context"
	"testing"
	"time"
)

const (
	gidGHistA       = 9440001
	gidGHistB       = 9440002
	gidGHistOrphan  = 9440003 // we'll insert history then DELETE the guild row
)

func putGuildHistoryCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	// Cleanup history first (child), then guild rows (parent). Even though
	// we have no FK, this order matters if a future migration adds one.
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM guild_history WHERE guild_id BETWEEN 9440001 AND 9440099`); err != nil {
		t.Fatalf("putGuildHistoryCleanup guild_history: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM guild WHERE id BETWEEN 9440001 AND 9440099`); err != nil {
		t.Fatalf("putGuildHistoryCleanup guild: %v", err)
	}
}

func TestPutGuildHistory(t *testing.T) {
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

	putGuildHistoryCleanup(t, ctx, pool)
	t.Cleanup(func() { putGuildHistoryCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{gidGHistA, "HistLegionA"},
		{gidGHistB, "HistLegionB"},
		{gidGHistOrphan, "HistLegionOrphan"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name) VALUES ($1, $2)`,
			seed.id, seed.name); err != nil {
			t.Fatalf("seed guild %d: %v", seed.id, err)
		}
	}

	t.Run("first put inserts 1 row, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putguildhistory",
			gidGHistA, int32(1700001000), int16(1), "PlayerJoined", "PlayerName",
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first: got %d, want 1", affected)
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM guild_history WHERE guild_id = $1`,
			gidGHistA).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("rows: got %d, want 1", cnt)
		}

		var (
			eventDate                   int32
			eventType                   int16
			eventParam, eventParam2     string
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT event_date, event_type, event_param, event_param2
			   FROM guild_history WHERE guild_id = $1`, gidGHistA).Scan(
			&eventDate, &eventType, &eventParam, &eventParam2); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if eventDate != 1700001000 || eventType != 1 ||
			eventParam != "PlayerJoined" || eventParam2 != "PlayerName" {
			t.Fatalf("values: got date=%d type=%d p=%q p2=%q",
				eventDate, eventType, eventParam, eventParam2)
		}
	})

	t.Run("5 puts on same guild → 5 rows in chrono order", func(t *testing.T) {
		// Wipe to clean state (we just put 1 row above; want a precise count).
		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM guild_history WHERE guild_id = $1`, gidGHistA); err != nil {
			t.Fatalf("inner-cleanup: %v", err)
		}

		events := []struct {
			date        int32
			etype       int16
			param, prm2 string
		}{
			{1700002000, 1, "Joined", "Alice"},
			{1700002100, 2, "Promoted", "Alice"},
			{1700002200, 3, "Demoted", "Bob"},
			{1700002300, 4, "Left", "Bob"},
			{1700002400, 5, "Renamed", "OldName,NewName"},
		}
		for _, ev := range events {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putguildhistory",
				gidGHistA, ev.date, ev.etype, ev.param, ev.prm2,
			).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow %s: %v", ev.param, err)
			}
			if affected != 1 {
				t.Fatalf("%s: got %d, want 1", ev.param, affected)
			}
		}

		// Verify order via the index (event_date DESC) — newest first.
		rows, err := pool.Inner().Query(ctx,
			`SELECT event_date, event_param FROM guild_history
			  WHERE guild_id = $1 ORDER BY event_date ASC`, gidGHistA)
		if err != nil {
			t.Fatalf("query: %v", err)
		}
		defer rows.Close()

		i := 0
		for rows.Next() {
			var date int32
			var param string
			if err := rows.Scan(&date, &param); err != nil {
				t.Fatalf("scan: %v", err)
			}
			if date != events[i].date || param != events[i].param {
				t.Fatalf("row %d: got date=%d param=%q, want %d/%q",
					i, date, param, events[i].date, events[i].param)
			}
			i++
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("rows.Err: %v", err)
		}
		if i != 5 {
			t.Fatalf("rows: got %d, want 5", i)
		}
	})

	t.Run("duplicate put ALSO inserts (no UNIQUE — append-only audit)", func(t *testing.T) {
		// History is intentionally not deduplicated; replays of the same
		// event are evidence in their own right.
		base := struct {
			date        int32
			etype       int16
			param, prm2 string
		}{1700003000, 9, "GuildEvent", "param2"}

		for i := 0; i < 3; i++ {
			var affected int
			if err := pool.CallSPRow(ctx, "aion_putguildhistory",
				gidGHistB, base.date, base.etype, base.param, base.prm2,
			).Scan(&affected); err != nil {
				t.Fatalf("CallSPRow #%d: %v", i+1, err)
			}
			if affected != 1 {
				t.Fatalf("dup #%d: got %d, want 1", i+1, affected)
			}
		}

		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM guild_history
			  WHERE guild_id = $1 AND event_date = $2 AND event_type = $3
			    AND event_param = $4 AND event_param2 = $5`,
			gidGHistB, base.date, base.etype, base.param, base.prm2,
		).Scan(&cnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if cnt != 3 {
			t.Fatalf("dup rows: got %d, want 3 (no UNIQUE constraint)", cnt)
		}
	})

	t.Run("neighbour isolation: A's puts don't appear under B's guild_id", func(t *testing.T) {
		// Put a fresh row on A.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putguildhistory",
			gidGHistA, int32(1700004000), int16(7), "PerturbA", "x",
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if affected != 1 {
			t.Fatalf("A: got %d, want 1", affected)
		}

		// Verify that NO history row under B has the "PerturbA" param.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM guild_history
			  WHERE guild_id = $1 AND event_param = 'PerturbA'`,
			gidGHistB).Scan(&cnt); err != nil {
			t.Fatalf("count B: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("B leaked from A: got %d rows with PerturbA", cnt)
		}
	})

	t.Run("history survives parent guild deletion (no FK)", func(t *testing.T) {
		// Insert a history row, then delete the parent guild.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_putguildhistory",
			gidGHistOrphan, int32(1700005000), int16(99), "PreDelete", "",
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow orphan: %v", err)
		}
		if affected != 1 {
			t.Fatalf("orphan put: got %d, want 1", affected)
		}

		if _, err := pool.Inner().Exec(ctx,
			`DELETE FROM guild WHERE id = $1`, gidGHistOrphan); err != nil {
			t.Fatalf("delete guild: %v", err)
		}

		// History row must still be there (forensics) — there is no FK.
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM guild_history WHERE guild_id = $1`,
			gidGHistOrphan).Scan(&cnt); err != nil {
			t.Fatalf("count orphan: %v", err)
		}
		if cnt != 1 {
			t.Fatalf("orphan history vanished: got %d, want 1", cnt)
		}
	})
}
