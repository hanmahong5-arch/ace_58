// Package database — integration test for aion_SetGuildEmblem.
//
// Pure UPDATE on the guild row (sets emblem version + last_version + bg_color
// + raw image bytea). Bug-for-bug NCSoft: no existence guard on guild_id; an
// UPDATE on a missing/deleted guild silently no-ops with rows-affected=0.
//
// Test matrix:
//   - happy path: existing guild → 1 row updated, all 4 columns hold new vals
//   - rebind: second SetEmblem on same guild fully overwrites earlier values
//   - missing guild: SetEmblem on unseeded id → 0 rows (no error)
//   - neighbour isolation: SetEmblem on guild A doesn't perturb guild B
package database

import (
	"bytes"
	"context"
	"testing"
	"time"
)

const (
	gidEmblemA = 9420001 // primary target legion
	gidEmblemB = 9420002 // neighbour legion (must not be touched)
	gidEmblemMissing = 9420099 // never seeded — proves missing-guild no-op
)

func setGuildEmblemCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM guild WHERE id BETWEEN 9420001 AND 9420099`); err != nil {
		t.Fatalf("setGuildEmblemCleanup guild: %v", err)
	}
}

func TestSetGuildEmblem(t *testing.T) {
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

	setGuildEmblemCleanup(t, ctx, pool)
	t.Cleanup(func() { setGuildEmblemCleanup(t, context.Background(), pool) })

	// Seed 2 sentinel legions. emblem columns default to 0 / 0 / 0 / NULL.
	for _, seed := range []struct {
		id   int
		name string
	}{
		{gidEmblemA, "EmblemLegionA"},
		{gidEmblemB, "EmblemLegionB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name) VALUES ($1, $2)`,
			seed.id, seed.name); err != nil {
			t.Fatalf("seed guild %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: existing guild → 1 row, all 4 cols persisted", func(t *testing.T) {
		var (
			version       int16 = 7
			lastVersion   int16 = 6
			bgColor       int32 = 0x00FF8800
			emblem              = []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A} // PNG magic + tail
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildemblem",
			gidEmblemA, version, lastVersion, bgColor, emblem).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		var (
			gotVersion, gotLast int16
			gotBgColor          int32
			gotEmblem           []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT emblem_img_version, emblem_img_last_version, emblem_bgcolor, emblem_img
			   FROM guild WHERE id = $1`, gidEmblemA).Scan(
			&gotVersion, &gotLast, &gotBgColor, &gotEmblem); err != nil {
			t.Fatalf("verify: %v", err)
		}
		if gotVersion != version {
			t.Fatalf("version: got %d, want %d", gotVersion, version)
		}
		if gotLast != lastVersion {
			t.Fatalf("last_version: got %d, want %d", gotLast, lastVersion)
		}
		if gotBgColor != bgColor {
			t.Fatalf("bg_color: got %d, want %d", gotBgColor, bgColor)
		}
		if !bytes.Equal(gotEmblem, emblem) {
			t.Fatalf("emblem bytes: got %v, want %v", gotEmblem, emblem)
		}
	})

	t.Run("rebind: second SetEmblem fully overwrites earlier values", func(t *testing.T) {
		var (
			version2     int16 = 8
			lastVersion2 int16 = 7 // = previous version (typical NCSoft semantics)
			bgColor2     int32 = 0x000044AA
			emblem2            = []byte{0xDE, 0xAD, 0xBE, 0xEF}
		)
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildemblem",
			gidEmblemA, version2, lastVersion2, bgColor2, emblem2).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow rebind: %v", err)
		}
		if affected != 1 {
			t.Fatalf("rebind: got %d, want 1", affected)
		}

		var (
			gotVersion, gotLast int16
			gotBgColor          int32
			gotEmblem           []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT emblem_img_version, emblem_img_last_version, emblem_bgcolor, emblem_img
			   FROM guild WHERE id = $1`, gidEmblemA).Scan(
			&gotVersion, &gotLast, &gotBgColor, &gotEmblem); err != nil {
			t.Fatalf("verify rebind: %v", err)
		}
		if gotVersion != version2 || gotLast != lastVersion2 ||
			gotBgColor != bgColor2 || !bytes.Equal(gotEmblem, emblem2) {
			t.Fatalf("rebind not idempotent: v=%d last=%d bg=%d emblem=%v",
				gotVersion, gotLast, gotBgColor, gotEmblem)
		}
	})

	t.Run("missing guild: SetEmblem on unseeded id → 0 rows (no error)", func(t *testing.T) {
		// Bug-for-bug NCSoft: silently no-ops, no error raised.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildemblem",
			gidEmblemMissing, int16(1), int16(0), int32(0), []byte{0x01}).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing guild: got %d, want 0", affected)
		}
	})

	t.Run("neighbour isolation: A's set doesn't perturb B", func(t *testing.T) {
		// B's emblem columns must remain at scaffold defaults: 0/0/0/NULL.
		var (
			bV, bL    int16
			bBg       int32
			bEmblem   []byte
		)
		if err := pool.Inner().QueryRow(ctx,
			`SELECT emblem_img_version, emblem_img_last_version, emblem_bgcolor, emblem_img
			   FROM guild WHERE id = $1`, gidEmblemB).Scan(
			&bV, &bL, &bBg, &bEmblem); err != nil {
			t.Fatalf("read B: %v", err)
		}
		if bV != 0 || bL != 0 || bBg != 0 {
			t.Fatalf("B leaked from A: v=%d last=%d bg=%d", bV, bL, bBg)
		}
		if bEmblem != nil {
			t.Fatalf("B emblem leaked: got %v, want nil", bEmblem)
		}
	})
}
