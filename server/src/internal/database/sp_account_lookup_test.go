// Package database — integration tests for the batch-24 account-lookup pair:
// aion_getvirtualauthaccountid (00257) / aion_getaccessallowaccount (00258).
//
// Both are pure read SPs:
//   - 00257 maps account_name → account_id from user_data (LIMIT 1, picks any
//     char belonging to the named account).
//   - 00258 enumerates the live access_allow_account whitelist.
//
// Test matrix:
//   - 00257 returns the expected account_id when a char exists for the name.
//   - 00257 returns the empty set when no char carries that account_name.
//   - 00257 picks SOME row (LIMIT 1, no ORDER BY) when the name has multiple
//     chars — we just verify the returned id is one of the seeded ids.
//   - 00258 returns only status=0 rows.
//   - 00258 omits suspended (status=1) and revoked (status=2) entries.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidVAuthA = 9640050 // first char on shared account
	cidVAuthB = 9640051 // second char on the same shared account (LIMIT 1 race)
	cidVAuthC = 9640052 // distinct account, distinct name

	accIDShared   = 770001
	accIDStandalone = 770002
	accNameShared = "vauth_share"
	accNameStandalone = "vauth_solo"
	accNameMissing    = "vauth_gap_xx"

	// access_allow_account whitelist test ids.
	accAllowLive    = 770010 // status=0  → must appear
	accAllowExpired = 770011 // status=1  → must NOT appear
	accAllowRevoked = 770012 // status=2  → must NOT appear
)

func accountLookupCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9640050 AND 9640059`); err != nil {
		t.Fatalf("accountLookupCleanup user_data: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM access_allow_account WHERE account_id BETWEEN 770010 AND 770019`); err != nil {
		t.Fatalf("accountLookupCleanup access_allow: %v", err)
	}
}

func TestGetVirtualAuthAccountId(t *testing.T) {
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

	accountLookupCleanup(t, ctx, pool)
	t.Cleanup(func() { accountLookupCleanup(t, context.Background(), pool) })

	// Seed three user_data rows: two on a shared account, one standalone.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data (char_id, name, account_id, account_name)
		 VALUES ($1, 'vA', $2, $3),
		        ($4, 'vB', $5, $6),
		        ($7, 'vC', $8, $9)`,
		cidVAuthA, accIDShared, accNameShared,
		cidVAuthB, accIDShared, accNameShared,
		cidVAuthC, accIDStandalone, accNameStandalone); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	t.Run("standalone name resolves to the lone account_id", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getvirtualauthaccountid", accNameStandalone)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		if !rows.Next() {
			t.Fatalf("standalone: zero rows, want 1")
		}
		var got int
		if err := rows.Scan(&got); err != nil {
			t.Fatalf("scan: %v", err)
		}
		if got != accIDStandalone {
			t.Fatalf("standalone account_id: got %d, want %d", got, accIDStandalone)
		}
		if rows.Next() {
			t.Fatalf("standalone: LIMIT 1 violated, extra rows present")
		}
	})

	t.Run("shared name yields the shared account_id (any LIMIT 1 row)", func(t *testing.T) {
		// Two chars share account_id; LIMIT 1 with no ORDER BY may return
		// either, but both have the SAME account_id, so the test is stable.
		rows, err := pool.CallSP(ctx, "aion_getvirtualauthaccountid", accNameShared)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		if !rows.Next() {
			t.Fatalf("shared: zero rows, want 1")
		}
		var got int
		if err := rows.Scan(&got); err != nil {
			t.Fatalf("scan: %v", err)
		}
		if got != accIDShared {
			t.Fatalf("shared account_id: got %d, want %d", got, accIDShared)
		}
		if rows.Next() {
			t.Fatalf("shared: LIMIT 1 violated, extra rows present")
		}
	})

	t.Run("missing name returns empty set", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getvirtualauthaccountid", accNameMissing)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		if rows.Next() {
			t.Fatalf("missing: got a row, want empty set")
		}
	})
}

func TestGetAccessAllowAccount(t *testing.T) {
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

	accountLookupCleanup(t, ctx, pool)
	t.Cleanup(func() { accountLookupCleanup(t, context.Background(), pool) })

	// Seed three rows: one live, one expired, one revoked. Only the live row
	// should appear in the SP output.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO access_allow_account (account_id, account_name, status)
		 VALUES ($1, 'allow_live',    0),
		        ($2, 'allow_expired', 1),
		        ($3, 'allow_revoked', 2)`,
		accAllowLive, accAllowExpired, accAllowRevoked); err != nil {
		t.Fatalf("seed access_allow_account: %v", err)
	}

	rows, err := pool.CallSP(ctx, "aion_getaccessallowaccount")
	if err != nil {
		t.Fatalf("CallSP: %v", err)
	}
	defer rows.Close()

	// Collect all rows in our test band; we ignore stray rows belonging to
	// other tests (no ORDER BY contract guarantees insertion order).
	seen := make(map[int]string)
	for rows.Next() {
		var id int
		var name string
		if err := rows.Scan(&id, &name); err != nil {
			t.Fatalf("scan: %v", err)
		}
		// Filter to our band so unrelated leaked rows do not skew the test.
		if id >= 770010 && id <= 770019 {
			seen[id] = name
		}
	}
	if rows.Err() != nil {
		t.Fatalf("rows.Err: %v", rows.Err())
	}

	if name, ok := seen[accAllowLive]; !ok {
		t.Fatalf("status=0 row missing from output (got %v)", seen)
	} else if name != "allow_live" {
		t.Fatalf("status=0 row name: got %q, want %q", name, "allow_live")
	}
	if _, ok := seen[accAllowExpired]; ok {
		t.Fatalf("status=1 row leaked into output")
	}
	if _, ok := seen[accAllowRevoked]; ok {
		t.Fatalf("status=2 row leaked into output")
	}
}
