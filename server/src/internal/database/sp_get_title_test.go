// Package database — integration test for aion_GetTitle.
//
// Returns (title_id, is_have, expired_time) for every title row owned by the
// char (no filter on expired vs unexpired — client decides display).
//
// Test matrix:
//   - owner with mix of equipped/unequipped + perma/expiring: all rows surface,
//     bool round-trips, expired_time round-trips
//   - owner with no titles: 0 rows
//   - char_id isolation: ownerA query never returns ownerB rows
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidTitleA     = 9001960 // owner with 3 titles (1 equipped, 1 unequipped perma, 1 expiring)
	cidTitleB     = 9001961 // owner with 1 title (control / isolation)
	cidTitleEmpty = 9001962 // owner with 0 titles
)

func getTitleCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_title WHERE char_id BETWEEN 9001960 AND 9001999`); err != nil {
		t.Fatalf("getTitleCleanup user_title: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001960 AND 9001999`); err != nil {
		t.Fatalf("getTitleCleanup user_data: %v", err)
	}
}

func TestGetTitle(t *testing.T) {
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

	getTitleCleanup(t, ctx, pool)
	t.Cleanup(func() { getTitleCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidTitleA, "TitleA"},
		{cidTitleB, "TitleB"},
		{cidTitleEmpty, "TitleEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "tt_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	type seedRow struct {
		charID, titleID int
		isHave          bool
		expiredTime     int64
	}
	for _, r := range []seedRow{
		{cidTitleA, 100, true, 0},          // equipped, permanent
		{cidTitleA, 200, false, 1700000000}, // unequipped, expires later
		{cidTitleA, 300, false, 0},         // unequipped, permanent
		{cidTitleB, 999, true, 1800000000}, // sentinel for boundary check
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_title(char_id, title_id, is_have, expired_time)
			 VALUES ($1, $2, $3, $4)`,
			r.charID, r.titleID, r.isHave, r.expiredTime); err != nil {
			t.Fatalf("seed title (%d,%d): %v", r.charID, r.titleID, err)
		}
	}

	t.Run("owner with mixed titles returns all rows ordered by title_id", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_gettitle", cidTitleA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			titleID     int32
			isHave      bool
			expiredTime int64
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.titleID, &o.isHave, &o.expiredTime); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("row count: got %d, want 3", len(got))
		}
		// ORDER BY title_id ASC → 100, 200, 300
		want := []out{
			{100, true, 0},
			{200, false, 1700000000},
			{300, false, 0},
		}
		for i, w := range want {
			if got[i] != w {
				t.Fatalf("row[%d]: got %+v, want %+v", i, got[i], w)
			}
		}
	})

	t.Run("owner with no titles returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_gettitle", cidTitleEmpty)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var n int
		for rs.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("empty owner: got %d rows, want 0", n)
		}
	})

	t.Run("char_id boundary: ownerB sentinel does not leak into ownerA", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_gettitle", cidTitleB)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()
		var (
			n           int
			titleID     int32
			isHave      bool
			expiredTime int64
		)
		for rs.Next() {
			if err := rs.Scan(&titleID, &isHave, &expiredTime); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 {
			t.Fatalf("ownerB row count: got %d, want 1", n)
		}
		if titleID != 999 || !isHave || expiredTime != 1800000000 {
			t.Fatalf("ownerB row: got (%d,%v,%d), want (999,true,1800000000)",
				titleID, isHave, expiredTime)
		}
	})
}
