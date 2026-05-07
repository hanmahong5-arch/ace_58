// Package database — integration test for aion_GetUserQina.
//
// Returns the bag-kinah row (name_id=182400001, warehouse=0) as (id, amount).
// Verifies: missing char → 0 rows, fresh char with no kinah → 0 rows,
// happy path → exact (id, amount), warehouse-bucket kinah is filtered out,
// duplicate-row corruption surfaces the lowest-id row deterministically.
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidQinaMissing   = 9001099 // never inserted
	cidQinaNoKinah   = 9001000 // row exists but has zero kinah items
	cidQinaHappy     = 9001001 // single bag kinah row
	cidQinaWhStacked = 9001002 // bag + warehouse kinah; warehouse must be ignored
	cidQinaDup       = 9001003 // pathological: two bag rows; lowest id wins
)

func userQinaCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_item WHERE char_id BETWEEN 9001000 AND 9001099`); err != nil {
		t.Fatalf("userQinaCleanup user_item: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001000 AND 9001099`); err != nil {
		t.Fatalf("userQinaCleanup user_data: %v", err)
	}
}

func TestGetUserQina(t *testing.T) {
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

	userQinaCleanup(t, ctx, pool)
	t.Cleanup(func() { userQinaCleanup(t, context.Background(), pool) })

	// Seed user_data so any FK / soft-delete filtering elsewhere does not bite.
	for _, cid := range []int{cidQinaNoKinah, cidQinaHappy, cidQinaWhStacked, cidQinaDup} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1::INT, 'qina_'||$1::INT::TEXT, 'qu_'||$1::INT::TEXT)`,
			cid); err != nil {
			t.Fatalf("seed user_data %d: %v", cid, err)
		}
	}

	// Happy path — single bag kinah.
	var happyID int64
	if err := pool.Inner().QueryRow(ctx,
		`INSERT INTO user_item(char_id, name_id, amount, warehouse)
		 VALUES ($1, 182400001, 12345678, 0) RETURNING id`,
		cidQinaHappy).Scan(&happyID); err != nil {
		t.Fatalf("seed happy: %v", err)
	}

	// Warehouse bucket — bag has 100, warehouse(=2) has 9999999.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_item(char_id, name_id, amount, warehouse) VALUES
		 ($1, 182400001, 100, 0),
		 ($1, 182400001, 9999999, 2)`,
		cidQinaWhStacked); err != nil {
		t.Fatalf("seed warehouse stacked: %v", err)
	}

	// Duplicate: two bag rows, smaller id wins.
	var dupLowID int64
	if err := pool.Inner().QueryRow(ctx,
		`INSERT INTO user_item(char_id, name_id, amount, warehouse)
		 VALUES ($1, 182400001, 1, 0) RETURNING id`,
		cidQinaDup).Scan(&dupLowID); err != nil {
		t.Fatalf("seed dup low: %v", err)
	}
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_item(char_id, name_id, amount, warehouse) VALUES ($1, 182400001, 999, 0)`,
		cidQinaDup); err != nil {
		t.Fatalf("seed dup high: %v", err)
	}

	t.Run("missing char returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserqina", cidQinaMissing)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing: got %d rows, want 0", n)
		}
	})

	t.Run("char without kinah returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserqina", cidQinaNoKinah)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("no-kinah: got %d rows, want 0", n)
		}
	})

	t.Run("happy path returns exact id and amount", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserqina", cidQinaHappy)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n      int
			id     int64
			amount int64
		)
		for rows.Next() {
			if err := rows.Scan(&id, &amount); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || id != happyID || amount != 12345678 {
			t.Fatalf("happy: n=%d id=%d amount=%d, want n=1 id=%d amount=12345678",
				n, id, amount, happyID)
		}
	})

	t.Run("warehouse rows filtered out", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserqina", cidQinaWhStacked)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n      int
			id     int64
			amount int64
		)
		for rows.Next() {
			if err := rows.Scan(&id, &amount); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || amount != 100 {
			t.Fatalf("warehouse stacked: n=%d amount=%d, want n=1 amount=100 (bag only)",
				n, amount)
		}
	})

	t.Run("duplicate rows return lowest-id deterministically", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getuserqina", cidQinaDup)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var (
			n      int
			id     int64
			amount int64
		)
		for rows.Next() {
			if err := rows.Scan(&id, &amount); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			n++
		}
		if n != 1 || id != dupLowID || amount != 1 {
			t.Fatalf("dup: n=%d id=%d amount=%d, want n=1 id=%d amount=1 (lowest wins)",
				n, id, amount, dupLowID)
		}
	})
}
