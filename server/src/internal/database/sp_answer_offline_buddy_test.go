// Package database — integration test for aion_answer_offline_buddy.
//
// Five-branch return-code SP. Test matrix mirrors the NCSoft return catalogue
// (0/2/3/5) so each branch surfaces as its own assertion failure on regression.
//
// Test matrix:
//   - happy path → return 0; inviter→invitee row inserted; lev/class/gender/world/word hydrated
//   - already-friends → return 2; no second row inserted
//   - inviter wrong race → return 3; no row inserted
//   - inviter does not exist → return 3
//   - invitee at 200-cap → return 5
//   - inviter at 200-cap → return 5
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidAnsOffInvitee     = 9002300 // race=1
	cidAnsOffInviter     = 9002301 // race=1, lev=42, class=3, gender=true, world=210020000, daily_comment=...
	cidAnsOffOtherFac    = 9002302 // race=2 — wrong race
	cidAnsOffAlready     = 9002303 // already friend of invitee
	cidAnsOffCapInvitee  = 9002304 // saturated to 200
	cidAnsOffCapInviter  = 9002305 // saturated to 200
	cidAnsOffSpare       = 9002306
)

func answerOfflineBuddyCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	for _, q := range []string{
		`DELETE FROM user_buddy_list WHERE char_id BETWEEN 9002300 AND 9002599 OR buddy_id BETWEEN 9002300 AND 9002599`,
		`DELETE FROM user_data       WHERE char_id BETWEEN 9002300 AND 9002599`,
	} {
		if _, err := p.Inner().Exec(ctx, q); err != nil {
			t.Fatalf("answerOfflineBuddyCleanup %q: %v", q, err)
		}
	}
}

func TestAnswerOfflineBuddy(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	answerOfflineBuddyCleanup(t, ctx, pool)
	t.Cleanup(func() { answerOfflineBuddyCleanup(t, context.Background(), pool) })

	// Seed primary actors with full attribute set so the OUT-row hydration can
	// be asserted byte-for-byte. race=1 for the matched group; race=2 for the
	// cross-faction control char.
	type seed struct {
		id    int
		name  string
		race  int
		lev   int
		class int
		gen   bool
		world int
		dword string
	}
	seeds := []seed{
		{cidAnsOffInvitee, "AnsInvtee", 1, 1, 0, false, 0, ""},
		{cidAnsOffInviter, "AnsInvter", 1, 42, 3, true, 210020000, "have a good day"},
		{cidAnsOffOtherFac, "AnsOtherFac", 2, 1, 0, false, 0, ""},
		{cidAnsOffAlready, "AnsAlready", 1, 5, 1, false, 0, ""},
		{cidAnsOffCapInvitee, "AnsCapInvtee", 1, 1, 0, false, 0, ""},
		{cidAnsOffCapInviter, "AnsCapInvter", 1, 1, 0, false, 0, ""},
		{cidAnsOffSpare, "AnsSpare", 1, 1, 0, false, 0, ""},
	}
	for _, s := range seeds {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id, race, lev, class, gender, world, daily_comment)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			s.id, s.name, "ans_"+s.name, s.race, s.lev, s.class, s.gen, s.world, s.dword); err != nil {
			t.Fatalf("seed %s: %v", s.name, err)
		}
	}

	// Pre-seed an active friendship so the "already friends" branch fires.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0)`,
		cidAnsOffInvitee, cidAnsOffAlready); err != nil {
		t.Fatalf("seed already-friend: %v", err)
	}

	scanRow := func(t *testing.T, charID int, charName string, inviterID int, inviterName string) (rc, lev, cls, gen, world int, word string) {
		t.Helper()
		if err := pool.CallSPRow(ctx, "aion_answer_offline_buddy",
			charID, charName, inviterID, inviterName).Scan(&rc, &lev, &cls, &gen, &world, &word); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		return
	}

	t.Run("happy path returns 0 and hydrates inviter info", func(t *testing.T) {
		rc, lev, cls, gen, world, word := scanRow(t,
			cidAnsOffInvitee, "AnsInvtee", cidAnsOffInviter, "AnsInvter")
		if rc != 0 {
			t.Fatalf("happy rc: got %d, want 0", rc)
		}
		if lev != 42 || cls != 3 || gen != 1 || world != 210020000 || word != "have a good day" {
			t.Fatalf("happy hydrate: lev=%d cls=%d gen=%d world=%d word=%q (want 42/3/1/210020000/'have a good day')",
				lev, cls, gen, world, word)
		}
		// Side-effect: inviter→invitee row exists with delete_flag=0.
		var df int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT delete_flag FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidAnsOffInviter, cidAnsOffInvitee).Scan(&df); err != nil {
			t.Fatalf("verify insert: %v", err)
		}
		if df != 0 {
			t.Fatalf("delete_flag: got %d, want 0", df)
		}
	})

	t.Run("already-friends returns 2 with no extra row", func(t *testing.T) {
		rc, _, _, _, _, _ := scanRow(t,
			cidAnsOffInvitee, "AnsInvtee", cidAnsOffAlready, "AnsAlready")
		if rc != 2 {
			t.Fatalf("already: got %d, want 2", rc)
		}
		var cnt int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_buddy_list WHERE char_id = $1 AND buddy_id = $2`,
			cidAnsOffAlready, cidAnsOffInvitee).Scan(&cnt); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("already-friends inserted reverse row: cnt=%d, want 0", cnt)
		}
	})

	t.Run("wrong-race inviter returns 3", func(t *testing.T) {
		rc, _, _, _, _, _ := scanRow(t,
			cidAnsOffInvitee, "AnsInvtee", cidAnsOffOtherFac, "AnsOtherFac")
		if rc != 3 {
			t.Fatalf("wrong race: got %d, want 3", rc)
		}
	})

	t.Run("non-existent inviter returns 3", func(t *testing.T) {
		rc, _, _, _, _, _ := scanRow(t,
			cidAnsOffInvitee, "AnsInvtee", 99999996, "Ghost")
		if rc != 3 {
			t.Fatalf("ghost: got %d, want 3", rc)
		}
	})

	t.Run("invitee at 200 cap returns 5", func(t *testing.T) {
		// Saturate cidAnsOffCapInvitee with 200 active buddy_list rows.
		// 9002400..9002599 are dummy peer ids.
		for i := 0; i < 200; i++ {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0)
				 ON CONFLICT DO NOTHING`,
				cidAnsOffCapInvitee, 9002400+i); err != nil {
				t.Fatalf("saturate invitee: %v", err)
			}
		}

		rc, _, _, _, _, _ := scanRow(t,
			cidAnsOffCapInvitee, "AnsCapInvtee", cidAnsOffSpare, "AnsSpare")
		if rc != 5 {
			t.Fatalf("invitee cap: got %d, want 5", rc)
		}
	})

	t.Run("inviter at 200 cap returns 5", func(t *testing.T) {
		for i := 0; i < 200; i++ {
			if _, err := pool.Inner().Exec(ctx,
				`INSERT INTO user_buddy_list(char_id, buddy_id, delete_flag) VALUES ($1, $2, 0)
				 ON CONFLICT DO NOTHING`,
				cidAnsOffCapInviter, 9002400+i); err != nil {
				t.Fatalf("saturate inviter: %v", err)
			}
		}

		rc, _, _, _, _, _ := scanRow(t,
			cidAnsOffSpare, "AnsSpare", cidAnsOffCapInviter, "AnsCapInvter")
		if rc != 5 {
			t.Fatalf("inviter cap: got %d, want 5", rc)
		}
	})
}
