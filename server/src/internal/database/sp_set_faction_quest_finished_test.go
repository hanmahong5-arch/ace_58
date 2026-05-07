// Package database — integration test for aion_SetFactionQuestFinished.
//
// Pure UPDATE on user_faction_friendship, mirror of 00183 (the *acquire*
// path) on the **finish path**: writes 3 cols (curid, curstate,
// lastfinishedtime) and atomically increments factionquest_finishedcount.
// Returns rows-affected so the caller can detect "no membership row" (0)
// vs "finish committed" (1).
//
// Test matrix:
//   - membership row exists       → UPDATE writes 3 cols + count++, returns 1
//   - second call same (char, faction) → second increment, returns 1, count = +2
//   - no membership row           → 0 rows affected, no row inserted
//   - acquired-side cols (lastacquiredtime) untouched
//   - friendship + jointime untouched
//   - neighbour membership row at the same faction is NOT modified
//   - alt faction row on same char is NOT modified
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidFactQuestFinA      = 9001975 // membership exists, primary target
	cidFactQuestFinB      = 9001976 // membership exists, neighbour
	cidFactQuestFinGone   = 9001977 // no membership row
	factionQuestFinFid    = 110     // faction id used for A and B
	factionQuestFinFidAlt = 210     // alt faction (only on A)
)

func setFactionQuestFinishedCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_faction_friendship WHERE char_id BETWEEN 9001975 AND 9001978`); err != nil {
		t.Fatalf("setFactionQuestFinishedCleanup user_faction_friendship: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001975 AND 9001978`); err != nil {
		t.Fatalf("setFactionQuestFinishedCleanup user_data: %v", err)
	}
}

func TestSetFactionQuestFinished(t *testing.T) {
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

	setFactionQuestFinishedCleanup(t, ctx, pool)
	t.Cleanup(func() { setFactionQuestFinishedCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidFactQuestFinA, "fqfA"},
		{cidFactQuestFinB, "fqfB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "fqf_"+seed.name); err != nil {
			t.Fatalf("seed user_data %d: %v", seed.id, err)
		}
	}

	// Membership rows. Seed factionquest_lastacquiredtime to a non-zero
	// sentinel so we can prove the SP leaves it intact (acquired-path col).
	// finishedcount starts at 5 so we can prove the +1 increment, not a
	// blanket overwrite.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_faction_friendship(
		    char_id, faction_id, friendship, jointime,
		    factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime,
		    factionquest_lastfinishedtime, factionquest_finishedcount)
		 VALUES
		    ($1, $2, 6000, 1700300000, 0, 0, 1701000000, 0, 5),
		    ($3, $2, 8000, 1700400000, 0, 0, 1701100000, 0, 9),
		    ($1, $4, 10000, 1700500000, 0, 0, 1701200000, 0, 2)`,
		cidFactQuestFinA, factionQuestFinFid, cidFactQuestFinB, factionQuestFinFidAlt); err != nil {
		t.Fatalf("seed user_faction_friendship: %v", err)
	}

	t.Run("first finish writes 3 cols + increments count, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setfactionquestfinished",
			cidFactQuestFinA, int16(factionQuestFinFid),
			66001, int16(4), 1714700000).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("first finish: got %d, want 1", affected)
		}

		var (
			curid, lastFinished, lastAcquired int
			curstate                          int16
			finishedCount                     int
			friendship, jointime              int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid, factionquest_curstate, factionquest_lastfinishedtime,
			        factionquest_finishedcount, factionquest_lastacquiredtime,
			        friendship, jointime
			   FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestFinA, factionQuestFinFid).Scan(
			&curid, &curstate, &lastFinished,
			&finishedCount, &lastAcquired,
			&friendship, &jointime); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if curid != 66001 || curstate != 4 || lastFinished != 1714700000 {
			t.Fatalf("written cols: got curid=%d state=%d finished=%d, want 66001 / 4 / 1714700000",
				curid, curstate, lastFinished)
		}
		if finishedCount != 6 {
			t.Fatalf("count not incremented: got %d, want 6 (seeded 5 + 1)", finishedCount)
		}
		// Acquired-side col untouched.
		if lastAcquired != 1701000000 {
			t.Fatalf("acquired col disturbed: got %d, want 1701000000", lastAcquired)
		}
		// Membership cols untouched.
		if friendship != 6000 || jointime != 1700300000 {
			t.Fatalf("membership cols disturbed: got friendship=%d jointime=%d, want 6000 / 1700300000",
				friendship, jointime)
		}
	})

	t.Run("second finish increments again (count = seeded + 2), returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setfactionquestfinished",
			cidFactQuestFinA, int16(factionQuestFinFid),
			66002, int16(5), 1714800000).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("second finish: got %d, want 1", affected)
		}

		// No duplicate row created.
		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestFinA, factionQuestFinFid).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 1 {
			t.Fatalf("rows after second finish: got %d, want 1", rowCnt)
		}

		// Count incremented again (now 7 = seeded 5 + 2).
		var (
			finishedCount, lastFinished int
			curstate                    int16
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_finishedcount, factionquest_lastfinishedtime,
			        factionquest_curstate
			   FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestFinA, factionQuestFinFid).Scan(&finishedCount, &lastFinished, &curstate); err != nil {
			t.Fatalf("verify second: %v", err)
		}
		if finishedCount != 7 {
			t.Fatalf("second increment: got count=%d, want 7", finishedCount)
		}
		if lastFinished != 1714800000 || curstate != 5 {
			t.Fatalf("second overwrite: got finished=%d state=%d, want 1714800000 / 5",
				lastFinished, curstate)
		}
	})

	t.Run("no membership row returns 0 and inserts nothing", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setfactionquestfinished",
			cidFactQuestFinGone, int16(factionQuestFinFid),
			66003, int16(1), 1714900000).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("no membership: got %d, want 0", affected)
		}

		// No phantom row inserted.
		var rowCnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_faction_friendship WHERE char_id = $1`,
			cidFactQuestFinGone).Scan(&rowCnt); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCnt != 0 {
			t.Fatalf("phantom row: got %d for missing-membership char, want 0", rowCnt)
		}
	})

	t.Run("neighbour membership row at the same faction is NOT modified", func(t *testing.T) {
		// Char B's row at faction=110 — finishedcount should still be the
		// seeded 9, curid still 0 (we only ever wrote A's row).
		var (
			curid         int
			finishedCount int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid, factionquest_finishedcount
			   FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestFinB, factionQuestFinFid).Scan(&curid, &finishedCount); err != nil {
			t.Fatalf("verify B: %v", err)
		}
		if curid != 0 || finishedCount != 9 {
			t.Fatalf("B leak: got curid=%d count=%d, want 0 / 9", curid, finishedCount)
		}
	})

	t.Run("alt faction row on same char is NOT modified", func(t *testing.T) {
		// Char A also has a row at faction=210 (alt); SP scopes by faction_id,
		// so this row's count must remain at the seeded 2.
		var (
			curid         int
			finishedCount int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT factionquest_curid, factionquest_finishedcount
			   FROM user_faction_friendship
			  WHERE char_id = $1 AND faction_id = $2`,
			cidFactQuestFinA, factionQuestFinFidAlt).Scan(&curid, &finishedCount); err != nil {
			t.Fatalf("verify alt: %v", err)
		}
		if curid != 0 || finishedCount != 2 {
			t.Fatalf("alt-faction leak: got curid=%d count=%d, want 0 / 2", curid, finishedCount)
		}
	})
}
