// Package database — integration test for aion_SetFactionQuestAcquired.
//
// Pure UPDATE on user_faction_friendship: writes 3 of the factionquest_*
// columns (curid, curstate, lastacquiredtime). Returns rows-affected so
// the caller can detect "no membership row" (0) vs "progress committed" (1).
//
// Test matrix:
//   - membership row exists      → UPDATE writes 3 cols, returns 1
//   - second call same (char, faction) → overwrite in place, returns 1
//   - no membership row          → 0 rows affected, no row inserted
//   - other factionquest_* cols (lastfinishedtime, finishedcount) untouched
//   - neighbour membership row at the same faction is NOT modified
//   - friendship + jointime (the membership-write columns) are NOT touched
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidFactQuestA      = 9001986 // membership exists, primary target
	cidFactQuestB      = 9001987 // membership exists, neighbour
	cidFactQuestGone   = 9001988 // no membership row
	factionQuestFid    = 100     // faction id used for A and B
	factionQuestFidAlt = 200     // alternate faction id (only on A) for col-untouched check
)

func setFactionQuestAcquiredCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_faction_friendship WHERE char_id BETWEEN 9001986 AND 9001989`); err != nil {
		t.Fatalf("setFactionQuestAcquiredCleanup user_faction_friendship: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001986 AND 9001989`); err != nil {
		t.Fatalf("setFactionQuestAcquiredCleanup user_data: %v", err)
	}
}

func TestSetFactionQuestAcquired(t *testing.T) {
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

	setFactionQuestAcquiredCleanup(t, ctx, pool)
	t.Cleanup(func() { setFactionQuestAcquiredCleanup(t, context.Background(), pool) })

	// user_data seeds (FK isn't enforced, but real flow always has user_data).
	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidFactQuestA, "fqA"},
		{cidFactQuestB, "fqB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "fq_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Membership rows: A and B at faction=100; A also at faction=200 (alt).
	// Pre-populate factionquest_lastfinishedtime + factionquest_finishedcount
	// to non-zero values so we can prove the UPDATE leaves them intact.
	// friendship + jointime also get non-zero values for the same reason.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_faction_friendship(
		    char_id, faction_id, friendship, jointime,
		    factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime,
		    factionquest_lastfinishedtime, factionquest_finishedcount)
		 VALUES
		    ($1, $2, 5000, 1700000000, 0, 0, 0, 1690000000, 7),
		    ($3, $2, 7777, 1700111111, 0, 0, 0, 1691111111, 3),
		    ($1, $4, 9999, 1700222222, 0, 0, 0, 1692222222, 5)`,
		cidFactQuestA, factionQuestFid, cidFactQuestB, factionQuestFidAlt); err != nil {
		t.Fatalf("seed user_faction_friendship: %v", err)
	}

	t.Run("first acquire writes 3 columns and returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setfactionquestacquired",
			cidFactQuestA, int16(factionQuestFid),
			55001, int16(2), 1714400000).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first acquire: got %d, want 1", affected)
		}

		var (
			curid, lastAcquired                int
			curstate                           int16
			lastFinished                       int
			finishedCount                      int
			friendship, jointime               int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime,
			        factionquest_lastfinishedtime, factionquest_finishedcount,
			        friendship, jointime
			   FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestA, factionQuestFid).Scan(
			&curid, &curstate, &lastAcquired,
			&lastFinished, &finishedCount,
			&friendship, &jointime); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if curid != 55001 || curstate != 2 || lastAcquired != 1714400000 {
			t.Fatalf("written cols: got curid=%d state=%d acquired=%d, want 55001 / 2 / 1714400000",
				curid, curstate, lastAcquired)
		}
		// Adjacent factionquest_* columns untouched.
		if lastFinished != 1690000000 || finishedCount != 7 {
			t.Fatalf("finish cols disturbed: got lastFinished=%d count=%d, want 1690000000 / 7",
				lastFinished, finishedCount)
		}
		// Membership cols untouched.
		if friendship != 5000 || jointime != 1700000000 {
			t.Fatalf("membership cols disturbed: got friendship=%d jointime=%d, want 5000 / 1700000000",
				friendship, jointime)
		}
	})

	t.Run("second acquire same (char, faction) overwrites in place", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setfactionquestacquired",
			cidFactQuestA, int16(factionQuestFid),
			55002, int16(3), 1714500000).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second acquire: got %d, want 1", affected)
		}

		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestA, factionQuestFid).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after update: got %d, want 1 (no duplicate insert)", rowCnt)
		}

		var (
			curid, lastAcquired int
			curstate            int16
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime
			   FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestA, factionQuestFid).Scan(&curid, &curstate, &lastAcquired); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if curid != 55002 || curstate != 3 || lastAcquired != 1714500000 {
			t.Fatalf("overwrite: got curid=%d state=%d acquired=%d, want 55002 / 3 / 1714500000",
				curid, curstate, lastAcquired)
		}
	})

	t.Run("no membership row returns 0 and inserts nothing", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setfactionquestacquired",
			cidFactQuestGone, int16(factionQuestFid),
			55003, int16(1), 1714600000).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("no membership: got %d, want 0", affected)
		}

		// Confirm no phantom row was created (UPDATE on no-match must NOT
		// upsert; that would silently corrupt the membership state).
		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship WHERE char_id = $1`,
			cidFactQuestGone).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 0 {
			t.Fatalf("phantom row: got %d rows for missing-membership char, want 0", rowCnt)
		}
	})

	t.Run("neighbour membership row at the same faction is NOT modified", func(t *testing.T) {
		// Char B's row at faction=100 — its factionquest_curid should still
		// be the seed value 0 (we only ever wrote A's row in this test).
		var curid int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestB, factionQuestFid).Scan(&curid); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if curid != 0 {
			t.Fatalf("B leak: got curid=%d, want 0", curid)
		}
	})

	t.Run("alt faction row on same char is NOT modified", func(t *testing.T) {
		// Char A also has a row at faction=200; the SP scopes by faction_id,
		// so this row must remain at its seeded zeros.
		var curid int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestA, factionQuestFidAlt).Scan(&curid); err != nil {
			t.Fatalf("verify alt: %v", err)
		}
		if curid != 0 {
			t.Fatalf("alt-faction leak: got curid=%d, want 0", curid)
		}
	})
}
