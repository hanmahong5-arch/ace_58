// Package database — integration test for aion_SetSkillSkin (per-row mutation
// of use_skin / expire_time on an existing user_skill_skin entry).
//
// SetSkillSkin only mutates — PutSkillSkin (00041) does the upsert. So we
// MUST seed via aion_putskillskin first, then test the four command_type
// branches:
//   3 (USE)    : use_skin := 1
//   4 (DIUSE)  : use_skin := 0
//   5 (EXPIRE) : use_skin := 0, expire_time := 0
//   other      : silent no-op (NCSoft contract; no error)
//
// And: a SET on a non-existent (char_id, skill_skin_id) is a silent no-op.
//
// char_id band: 9_600_040..9_600_059 (batch 22 — skill_skin sub-band).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	cidSetSkin_Use     = 9600040 // command_type=3 USE
	cidSetSkin_Diuse   = 9600041 // command_type=4 DIUSE
	cidSetSkin_Expire  = 9600042 // command_type=5 EXPIRE
	cidSetSkin_Unknown = 9600043 // unknown command_type → no-op
	cidSetSkin_Missing = 9600044 // SET on a row that doesn't exist → no-op

	skinIDA = 30001
)

func setSkillSkinCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_skill_skin WHERE char_id BETWEEN 9600040 AND 9600059`); err != nil {
		t.Fatalf("setSkillSkinCleanup: %v", err)
	}
}

// seedSkin upserts a skin row for `char_id`, `skin_id` with expire_time=expire and use_skin=0.
// 使用 CallSPExec — aion_putskillskin RETURNS VOID；CallSP+rs 不 Close 会泄露 conn 直到池耗尽。
func seedSkin(t *testing.T, ctx context.Context, p *Pool, charID, skinID int, expire int) {
	t.Helper()
	if err := p.CallSPExec(ctx, "aion_putskillskin",
		charID, skinID, expire); err != nil {
		t.Fatalf("seed PutSkillSkin char=%d skin=%d: %v", charID, skinID, err)
	}
}

func TestSetSkillSkin(t *testing.T) {
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

	setSkillSkinCleanup(t, ctx, pool)
	t.Cleanup(func() { setSkillSkinCleanup(t, context.Background(), pool) })

	t.Run("command_type=3 USE flips use_skin to 1, leaves expire intact", func(t *testing.T) {
		seedSkin(t, ctx, pool, cidSetSkin_Use, skinIDA, 1730000000)

		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Use, skinIDA, int16(3)); err != nil {
			t.Fatalf("USE: %v", err)
		}

		var (
			useSkin int16
			expire  int32
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_skin, expire_time FROM user_skill_skin
			  WHERE char_id=$1 AND skill_skin_id=$2`,
			cidSetSkin_Use, skinIDA).Scan(&useSkin, &expire); err != nil {
			t.Fatalf("verify USE: %v", err)
		}
		if useSkin != 1 || expire != 1730000000 {
			t.Fatalf("USE: use_skin=%d expire=%d, want 1/1730000000", useSkin, expire)
		}
	})

	t.Run("command_type=4 DIUSE flips use_skin to 0, leaves expire intact", func(t *testing.T) {
		seedSkin(t, ctx, pool, cidSetSkin_Diuse, skinIDA, 1731000000)

		// First USE so the next DIUSE has something to undo.
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Diuse, skinIDA, int16(3)); err != nil {
			t.Fatalf("pre-USE: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Diuse, skinIDA, int16(4)); err != nil {
			t.Fatalf("DIUSE: %v", err)
		}

		var (
			useSkin int16
			expire  int32
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_skin, expire_time FROM user_skill_skin
			  WHERE char_id=$1 AND skill_skin_id=$2`,
			cidSetSkin_Diuse, skinIDA).Scan(&useSkin, &expire); err != nil {
			t.Fatalf("verify DIUSE: %v", err)
		}
		if useSkin != 0 || expire != 1731000000 {
			t.Fatalf("DIUSE: use_skin=%d expire=%d, want 0/1731000000", useSkin, expire)
		}
	})

	t.Run("command_type=5 EXPIRE clears use_skin AND zeros expire_time", func(t *testing.T) {
		seedSkin(t, ctx, pool, cidSetSkin_Expire, skinIDA, 1732000000)

		// Equip first (use_skin=1) so we can verify EXPIRE clears it.
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Expire, skinIDA, int16(3)); err != nil {
			t.Fatalf("pre-USE: %v", err)
		}
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Expire, skinIDA, int16(5)); err != nil {
			t.Fatalf("EXPIRE: %v", err)
		}

		var (
			useSkin int16
			expire  int32
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_skin, expire_time FROM user_skill_skin
			  WHERE char_id=$1 AND skill_skin_id=$2`,
			cidSetSkin_Expire, skinIDA).Scan(&useSkin, &expire); err != nil {
			t.Fatalf("verify EXPIRE: %v", err)
		}
		if useSkin != 0 || expire != 0 {
			t.Fatalf("EXPIRE: use_skin=%d expire=%d, want 0/0", useSkin, expire)
		}
	})

	t.Run("unknown command_type is a silent no-op (NCSoft pin)", func(t *testing.T) {
		seedSkin(t, ctx, pool, cidSetSkin_Unknown, skinIDA, 1733000000)
		// Pre-equip so we can prove no branch ran.
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Unknown, skinIDA, int16(3)); err != nil {
			t.Fatalf("pre-USE: %v", err)
		}

		// Now apply an unknown command — must NOT raise, must NOT change row.
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Unknown, skinIDA, int16(99)); err != nil {
			t.Fatalf("unknown command: %v", err)
		}

		var (
			useSkin int16
			expire  int32
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT use_skin, expire_time FROM user_skill_skin
			  WHERE char_id=$1 AND skill_skin_id=$2`,
			cidSetSkin_Unknown, skinIDA).Scan(&useSkin, &expire); err != nil {
			t.Fatalf("verify no-op: %v", err)
		}
		// Row state unchanged from the pre-USE: use_skin=1, expire=1733000000.
		if useSkin != 1 || expire != 1733000000 {
			t.Fatalf("unknown no-op: use_skin=%d expire=%d, want 1/1733000000",
				useSkin, expire)
		}
	})

	t.Run("SET on missing (char,skin) is a silent no-op", func(t *testing.T) {
		// Do NOT seed cidSetSkin_Missing. The SP must not raise.
		if err := pool.CallSPExec(ctx, "aion_setskillskin",
			cidSetSkin_Missing, skinIDA, int16(3)); err != nil {
			t.Fatalf("missing-row USE: %v", err)
		}
		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM user_skill_skin WHERE char_id=$1`,
			cidSetSkin_Missing).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		if n != 0 {
			t.Fatalf("missing-row leaked rows: got %d, want 0", n)
		}
	})
}
