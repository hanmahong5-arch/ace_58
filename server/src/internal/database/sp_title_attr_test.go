// Package database — integration tests for the batch-24 char_title triplet:
// aion_setattrtitle (00254) / aion_updatetitle (00255) / aion_getcurtitle (00256).
//
// All three operate on the user_data + user_title pair already scaffolded by
// 00002 + 00008 + 00032 + 00162 + 00223. We exercise the round-trip:
//
//   1. Seed a fresh user_data row for our test char (char_id band 9_640_001 +).
//   2. SetAttrTitle bumps cur_title_attr_id and change_info_time atomically.
//   3. GetCurTitle returns both selectors in one row.
//   4. UpdateTitle UPSERTs into user_title (insert path + update path).
//   5. Verify rowcounts, persisted columns, and idempotency.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	// char_id band 9_640_001..9_640_099 reserved for batch 24 (R24-only).
	cidTitleAttrA   = 9640001 // primary subject of attr-title round-trip
	cidTitleAttrB   = 9640002 // neighbour row, must remain untouched
	cidTitleAttrGap = 9640003 // never seeded, used to assert 0-rowcount on missing
	cidTitleAttrUps = 9640004 // user_title UPSERT subject
)

func titleAttrCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	// Order matters: user_title FK-style depends on char_id, but no real FK
	// is declared so order is purely about test hygiene.
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_title WHERE char_id BETWEEN 9640001 AND 9640099`); err != nil {
		t.Fatalf("titleAttrCleanup user_title: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9640001 AND 9640099`); err != nil {
		t.Fatalf("titleAttrCleanup user_data: %v", err)
	}
}

func TestTitleAttrRoundTrip(t *testing.T) {
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

	titleAttrCleanup(t, ctx, pool)
	t.Cleanup(func() { titleAttrCleanup(t, context.Background(), pool) })

	// Seed two user_data rows. Default cur_title_id / cur_title_attr_id = 0
	// (column default added in 00032). change_info_time starts at 0 so we
	// can detect the SP bumping it.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data (char_id, name, account_name)
		 VALUES ($1, 'tA', 'acct_tA'),
		        ($2, 'tB', 'acct_tB'),
		        ($3, 'tU', 'acct_tU')`,
		cidTitleAttrA, cidTitleAttrB, cidTitleAttrUps); err != nil {
		t.Fatalf("seed user_data: %v", err)
	}

	t.Run("SetAttrTitle bumps cur_title_attr_id + change_info_time, returns 1", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setattrtitle",
			cidTitleAttrA, 4242).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow setattrtitle: %v", err)
		}
		if affected != 1 {
			t.Fatalf("setattrtitle: got %d, want 1", affected)
		}

		var attr int
		var ts int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cur_title_attr_id, change_info_time FROM user_data WHERE char_id = $1`,
			cidTitleAttrA).Scan(&attr, &ts); err != nil {
			t.Fatalf("verify columns: %v", err)
		}
		if attr != 4242 {
			t.Fatalf("cur_title_attr_id: got %d, want 4242", attr)
		}
		if ts <= 0 {
			t.Fatalf("change_info_time not bumped: got %d, want > 0", ts)
		}
	})

	t.Run("SetAttrTitle on missing char returns 0", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setattrtitle",
			cidTitleAttrGap, 999).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing char: got %d, want 0", affected)
		}
	})

	t.Run("SetAttrTitle does not leak into neighbour row", func(t *testing.T) {
		var attr int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cur_title_attr_id FROM user_data WHERE char_id = $1`,
			cidTitleAttrB).Scan(&attr); err != nil {
			t.Fatalf("verify neighbour: %v", err)
		}
		if attr != 0 {
			t.Fatalf("neighbour leak: cur_title_attr_id = %d, want 0", attr)
		}
	})

	t.Run("SetAttrTitle accepts 0 sentinel (clear the equipped attr-title)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setattrtitle",
			cidTitleAttrA, 0).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow zero: %v", err)
		}
		if affected != 1 {
			t.Fatalf("zero clear: got %d, want 1", affected)
		}
		var attr int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT cur_title_attr_id FROM user_data WHERE char_id = $1`,
			cidTitleAttrA).Scan(&attr); err != nil {
			t.Fatalf("verify zero: %v", err)
		}
		if attr != 0 {
			t.Fatalf("after zero set: got %d, want 0", attr)
		}
	})

	t.Run("GetCurTitle returns both selectors as a row", func(t *testing.T) {
		// First wire up cur_title_id via 00223 SetTitle so we can verify the
		// GetCurTitle pair-read returns both columns side by side.
		var setAffected int
		if err := pool.CallSPRow(ctx, "aion_settitle",
			cidTitleAttrA, 7777).Scan(&setAffected); err != nil {
			t.Fatalf("settitle: %v", err)
		}
		if setAffected != 1 {
			t.Fatalf("settitle rowcount: got %d, want 1", setAffected)
		}
		var setAttrAffected int
		if err := pool.CallSPRow(ctx, "aion_setattrtitle",
			cidTitleAttrA, 8888).Scan(&setAttrAffected); err != nil {
			t.Fatalf("setattrtitle re-set: %v", err)
		}
		if setAttrAffected != 1 {
			t.Fatalf("setattrtitle re-set rowcount: got %d, want 1", setAttrAffected)
		}

		rows, err := pool.CallSP(ctx, "aion_getcurtitle", cidTitleAttrA)
		if err != nil {
			t.Fatalf("CallSP getcurtitle: %v", err)
		}
		defer rows.Close()
		if !rows.Next() {
			t.Fatalf("getcurtitle: zero rows, want 1")
		}
		var titleID, attrID int
		if err := rows.Scan(&titleID, &attrID); err != nil {
			t.Fatalf("scan: %v", err)
		}
		if titleID != 7777 || attrID != 8888 {
			t.Fatalf("getcurtitle pair: got (%d, %d), want (7777, 8888)", titleID, attrID)
		}
		if rows.Next() {
			t.Fatalf("getcurtitle: extra rows, want exactly 1")
		}
	})

	t.Run("GetCurTitle on missing char returns empty set", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getcurtitle", cidTitleAttrGap)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		if rows.Next() {
			t.Fatalf("getcurtitle missing: got a row, want empty set")
		}
	})

	t.Run("UpdateTitle inserts a fresh user_title row", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_updatetitle",
			cidTitleAttrUps, 1001, true, int32(1700000000)).Scan(&affected); err != nil {
			t.Fatalf("updatetitle insert: %v", err)
		}
		if affected != 1 {
			t.Fatalf("updatetitle insert rowcount: got %d, want 1", affected)
		}

		var have bool
		var expired int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT is_have, expired_time FROM user_title WHERE char_id = $1 AND title_id = $2`,
			cidTitleAttrUps, 1001).Scan(&have, &expired); err != nil {
			t.Fatalf("verify insert: %v", err)
		}
		if !have || expired != 1700000000 {
			t.Fatalf("after insert: have=%v expired=%d, want true / 1700000000", have, expired)
		}
	})

	t.Run("UpdateTitle UPSERTs over an existing row", func(t *testing.T) {
		// Same (char, title) — flip is_have to false and shorten expiry.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_updatetitle",
			cidTitleAttrUps, 1001, false, int32(1700000099)).Scan(&affected); err != nil {
			t.Fatalf("updatetitle upsert: %v", err)
		}
		if affected != 1 {
			t.Fatalf("updatetitle upsert rowcount: got %d, want 1", affected)
		}

		var have bool
		var expired int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT is_have, expired_time FROM user_title WHERE char_id = $1 AND title_id = $2`,
			cidTitleAttrUps, 1001).Scan(&have, &expired); err != nil {
			t.Fatalf("verify upsert: %v", err)
		}
		if have || expired != 1700000099 {
			t.Fatalf("after upsert: have=%v expired=%d, want false / 1700000099", have, expired)
		}

		// Confirm we did NOT duplicate the row.
		var rowCount int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_title WHERE char_id = $1`,
			cidTitleAttrUps).Scan(&rowCount); err != nil {
			t.Fatalf("count: %v", err)
		}
		if rowCount != 1 {
			t.Fatalf("user_title row count after upsert: got %d, want 1", rowCount)
		}
	})

	t.Run("UpdateTitle accepts negative expired_time (pinned NCSoft signed-INT)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_updatetitle",
			cidTitleAttrUps, 2002, true, int32(-1)).Scan(&affected); err != nil {
			t.Fatalf("updatetitle neg: %v", err)
		}
		if affected != 1 {
			t.Fatalf("updatetitle neg rowcount: got %d, want 1", affected)
		}
		var expired int64
		if err := pool.Inner().QueryRow(ctx,
			`SELECT expired_time FROM user_title WHERE char_id = $1 AND title_id = $2`,
			cidTitleAttrUps, 2002).Scan(&expired); err != nil {
			t.Fatalf("verify neg: %v", err)
		}
		if expired != -1 {
			t.Fatalf("after neg: got %d, want -1", expired)
		}
	})
}
