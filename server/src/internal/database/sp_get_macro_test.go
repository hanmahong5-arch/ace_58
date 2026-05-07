// Package database — integration test for aion_GetMacro.
//
// Returns (slot_id, data) for every macro slot the char owns. Pairs with
// aion_SetMacro (00170) producer and aion_DelMacro (00171) reaper. The blob
// is opaque server-side; we verify byte-perfect round-trip and that
// no-rows + multi-rows + empty-blob all surface correctly.
//
// Test matrix:
//   - char with 3 macro slots (slot 0/3/11, distinct payloads) → all 3 surface in slot order
//   - char with 0 macros → 0 rows
//   - empty-blob slot ('\x' default) round-trips as []byte{} not NULL
package database

import (
	"bytes"
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidMacroGetA     = 9001940 // owner with 3 macro slots
	cidMacroGetEmpty = 9001941 // owner with 0 slots (control)
)

func getMacroCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_macro WHERE char_id BETWEEN 9001940 AND 9001949`); err != nil {
		t.Fatalf("getMacroCleanup user_macro: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001940 AND 9001949`); err != nil {
		t.Fatalf("getMacroCleanup user_data: %v", err)
	}
}

func TestGetMacro(t *testing.T) {
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

	getMacroCleanup(t, ctx, pool)
	t.Cleanup(func() { getMacroCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidMacroGetA, "MacGetA"},
		{cidMacroGetEmpty, "MacGetEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "mg_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	type seedRow struct {
		slotID int16
		data   []byte
	}
	// Distinct binary payloads to verify byte-perfect round-trip.
	// Slot 11 carries the empty-blob edge case ('\x' default).
	seeds := []seedRow{
		{0, []byte{0xDE, 0xAD, 0xBE, 0xEF}},
		{3, []byte{0x01, 0x02, 0x03, 0x04, 0x05}},
		{11, []byte{}}, // empty blob — must round-trip as zero-length, not NULL
	}
	for _, r := range seeds {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_macro(char_id, slot_id, data) VALUES ($1, $2, $3)`,
			cidMacroGetA, r.slotID, r.data); err != nil {
			t.Fatalf("seed slot=%d: %v", r.slotID, err)
		}
	}

	t.Run("owner returns all slots in slot order", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getmacro", cidMacroGetA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rs.Close()

		type out struct {
			slotID int16
			data   []byte
		}
		var got []out
		for rs.Next() {
			var o out
			if err := rs.Scan(&o.slotID, &o.data); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			got = append(got, o)
		}
		if len(got) != 3 {
			t.Fatalf("row count: got %d, want 3", len(got))
		}
		sort.Slice(got, func(i, j int) bool { return got[i].slotID < got[j].slotID })

		want := []out{
			{0, []byte{0xDE, 0xAD, 0xBE, 0xEF}},
			{3, []byte{0x01, 0x02, 0x03, 0x04, 0x05}},
			{11, []byte{}},
		}
		for i, w := range want {
			if got[i].slotID != w.slotID || !bytes.Equal(got[i].data, w.data) {
				t.Fatalf("row[%d]: got slot=%d data=%x, want slot=%d data=%x",
					i, got[i].slotID, got[i].data, w.slotID, w.data)
			}
		}
	})

	t.Run("owner with no slots returns 0 rows", func(t *testing.T) {
		rs, err := pool.CallSP(ctx, "aion_getmacro", cidMacroGetEmpty)
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
}
