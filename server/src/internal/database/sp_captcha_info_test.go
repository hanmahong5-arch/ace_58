// Package database — integration tests for the user_captcha SP triplet
// (00229 GetCaptchaInfo / 00230 SetCaptchaInfo / 00231 ClearCaptchaInfo).
//
// Domain: anti-bot captcha state, first introduced in batch 19. user_captcha
// is char-keyed and survives session restarts; ClearCaptchaInfo is a global
// daily-reset sweep with no parameters.
//
// Test matrix:
//   - GetCaptchaInfo on missing char → 0 rows (no implicit default row)
//   - SetCaptchaInfo INSERT branch → row appears with exact payload
//   - SetCaptchaInfo UPDATE branch → second call mutates fields, no dup
//   - GetCaptchaInfo round-trips the upserted payload, column order pinned
//   - ClearCaptchaInfo wipes all rows in band and reports correct count
//
// char_id band: 9_570_001..9_570_099 (R19 batch — captcha + error-ignore).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidCaptchaMiss   = 9570001 // never inserted, exercises 0-row branch
	cidCaptchaInsert = 9570002 // first call → INSERT branch
	cidCaptchaUpdate = 9570003 // covers INSERT then UPDATE branch
	cidCaptchaWipe1  = 9570004 // pre-clear seed
	cidCaptchaWipe2  = 9570005 // pre-clear seed
)

// captchaCleanup wipes the band before & after to keep tests hermetic.
// We constrain DELETE to the test band even though ClearCaptchaInfo is
// itself unscoped — that SP is exercised on a separate band-only fixture.
func captchaCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_captcha WHERE char_id BETWEEN 9570001 AND 9570099`); err != nil {
		t.Fatalf("captchaCleanup: %v", err)
	}
}

func TestCaptchaInfo(t *testing.T) {
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

	captchaCleanup(t, ctx, pool)
	t.Cleanup(func() { captchaCleanup(t, context.Background(), pool) })

	t.Run("get on missing char returns no rows", func(t *testing.T) {
		// No row pre-seeded — RETURNS TABLE function with 0 matches must
		// produce a Rows iterator that yields nothing (not an error, not
		// a nil-filled row). Pin the contract.
		rows, err := pool.CallSP(ctx, "aion_getcaptchainfo", int(cidCaptchaMiss))
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("missing char rows: got %d, want 0", n)
		}
	})

	t.Run("set inserts when char absent, payload round-trips", func(t *testing.T) {
		// SetCaptchaInfo args (positional, T-SQL order pinned):
		//   char_id, prohibition_flag, count, prohibition_time,
		//   elapsed_time, first_generation_time
		if err := pool.CallSPExec(ctx, "aion_setcaptchainfo",
			int(cidCaptchaInsert),
			int16(1),          // prohibition_flag (locked)
			int16(3),          // count
			int(1700001000),   // prohibition_time
			int(120),          // elapsed_time
			int(1699999000),   // first_generation_time
		); err != nil {
			t.Fatalf("CallSPExec set: %v", err)
		}

		// Read back via GetCaptchaInfo — verifies INSERT branch + column
		// ordering of the RETURNS TABLE.
		var (
			flag, count                             int16
			prohibitionTime, elapsedTime, firstGen int
		)
		if err := pool.CallSPRow(ctx, "aion_getcaptchainfo", int(cidCaptchaInsert)).
			Scan(&flag, &count, &prohibitionTime, &elapsedTime, &firstGen); err != nil {
			t.Fatalf("CallSPRow get: %v", err)
		}
		if flag != 1 || count != 3 || prohibitionTime != 1700001000 ||
			elapsedTime != 120 || firstGen != 1699999000 {
			t.Fatalf("payload roundtrip: flag=%d count=%d ptime=%d etime=%d fgen=%d",
				flag, count, prohibitionTime, elapsedTime, firstGen)
		}
	})

	t.Run("set on existing char takes UPDATE branch (no duplicate row)", func(t *testing.T) {
		// First insert.
		if err := pool.CallSPExec(ctx, "aion_setcaptchainfo",
			int(cidCaptchaUpdate),
			int16(0), int16(0), int(0), int(0), int(0),
		); err != nil {
			t.Fatalf("CallSPExec first: %v", err)
		}
		// Second call — must UPDATE, not INSERT (PK collision branch).
		if err := pool.CallSPExec(ctx, "aion_setcaptchainfo",
			int(cidCaptchaUpdate),
			int16(1),          // flag flips to locked
			int16(7),          // count escalates
			int(1700002000),
			int(999),
			int(1699998000),
		); err != nil {
			t.Fatalf("CallSPExec second: %v", err)
		}

		// Row count for this char must be exactly 1 — UPDATE, not duplicate.
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_captcha WHERE char_id=$1`,
			cidCaptchaUpdate).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 1 {
			t.Fatalf("upsert produced %d rows, want 1 (no dup pin)", n)
		}

		// Verify mutated payload via direct SELECT (cross-check Get path).
		var (
			flag, count                             int16
			prohibitionTime, elapsedTime, firstGen int
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT prohibition_flag, count, prohibition_time, elapsed_time, first_generation_time
			   FROM user_captcha WHERE char_id=$1`,
			cidCaptchaUpdate).Scan(&flag, &count, &prohibitionTime, &elapsedTime, &firstGen); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if flag != 1 || count != 7 || prohibitionTime != 1700002000 ||
			elapsedTime != 999 || firstGen != 1699998000 {
			t.Fatalf("update payload: flag=%d count=%d ptime=%d etime=%d fgen=%d",
				flag, count, prohibitionTime, elapsedTime, firstGen)
		}
	})

	t.Run("clear wipes all rows and returns affected count (band-isolated harness)", func(t *testing.T) {
		// ClearCaptchaInfo is unscoped (full-table DELETE) per NCSoft pin.
		// To exercise it without nuking concurrent test state, we run inside
		// a transaction that we always rollback — this verifies SP semantics
		// (DELETE + GET DIAGNOSTICS) without committing the wipe.
		tx, err := pool.Inner().Begin(ctx)
		if err != nil {
			t.Fatalf("Begin tx: %v", err)
		}
		defer func() { _ = tx.Rollback(ctx) }()

		// Seed two rows inside the tx so the wipe count is deterministic
		// relative to whatever lives outside.
		for _, cid := range []int{cidCaptchaWipe1, cidCaptchaWipe2} {
			if _, err := tx.Exec(ctx,
				`INSERT INTO user_captcha (char_id, prohibition_flag, count,
				    prohibition_time, elapsed_time, first_generation_time)
				 VALUES ($1, 0, 0, 0, 0, 0)
				 ON CONFLICT (char_id) DO NOTHING`, cid); err != nil {
				t.Fatalf("seed cid=%d: %v", cid, err)
			}
		}

		// Snapshot pre-clear row count (whole table — wipe is unscoped).
		var pre int64
		if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM user_captcha`).Scan(&pre); err != nil {
			t.Fatalf("pre count: %v", err)
		}

		// Invoke ClearCaptchaInfo — returns BIGINT row count.
		var affected int64
		if err := tx.QueryRow(ctx, `SELECT aion_clearcaptchainfo()`).Scan(&affected); err != nil {
			t.Fatalf("aion_clearcaptchainfo: %v", err)
		}
		if affected != pre {
			t.Fatalf("affected=%d, want pre=%d (full-table wipe pin)", affected, pre)
		}

		// Post-wipe table must be empty inside this tx.
		var post int64
		if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM user_captcha`).Scan(&post); err != nil {
			t.Fatalf("post count: %v", err)
		}
		if post != 0 {
			t.Fatalf("post-wipe count: got %d, want 0", post)
		}
		// tx.Rollback in deferred — no commit, outside-tx rows preserved.
	})
}
