// Package database — integration test for the house_field SP triplet
// (00261 PutHouseField / 00262 SetHouseField / 00263 RemoveHouseField).
//
// Domain (`house_field`, batch 25):
//   First-introduction of the `house_field` decoration manifest table.
//   Three SPs cover the row lifecycle. The Put path drops 3 "useless
//   param" columns (legion_id / emblem_*) by NCSoft's own admission;
//   the Set path writes them. Set ALSO silently overrides @owner_name
//   from user_data.name (NCSoft mirrors via USER_ID column) — that
//   override is the most surprising behaviour and gets dedicated
//   coverage here.
//
// Test matrix:
//   - PutHouseField inserts a row, returns 1; payload round-trips
//   - PutHouseField on duplicate id returns 0 (ON CONFLICT DO NOTHING)
//   - PutHouseField does NOT write legion_id / emblem_version /
//     emblem_bgcolor — those stay at column DEFAULT 0 (NCSoft pin)
//   - SetHouseField on existing row updates all decoration columns +
//     legion/emblem fields
//   - SetHouseField overrides owner_name from user_data.name when row
//     present (NCSoft pin)
//   - SetHouseField keeps the supplied owner_name when user_data row
//     is absent (NCSoft `select @x = ...` is no-op on empty result)
//   - SetHouseField on missing id returns 0
//   - RemoveHouseField on existing row returns 1; row gone
//   - RemoveHouseField on missing id returns 0
//
// id band: 9_650_041..9_650_099 reuses the R25 char_id band as house_id
// space (no collision; the band is reserved for this batch).
package database

import (
	"context"
	"testing"
	"time"
)

const (
	hfIDBasic     = 9650041 // basic Put/Set/Remove path
	hfIDDup       = 9650042 // duplicate Put returns 0
	hfIDOverride  = 9650043 // owner_name override from user_data.name
	hfIDNoOvr     = 9650044 // no user_data row → keep supplied owner_name
	hfIDMissing   = 9650099 // never inserted; exercises 0-affected paths
	hfOwnerCanon  = 9650088 // user_data char_id for canonical-name path
	hfOwnerOrphan = 9650089 // owner with NO user_data row → keep param
)

// Mirrors the NCSoft / 00261 column ordering. Helper to keep the test
// readable without dozens of inline literals at every call site.
type hfRow struct {
	id, addrID, buildingNameID, ownerID                    int
	ownerType, ownerRace, state, permission, commentState  int16
	roof, outwall, frame, door, garden, fence              int
	inwall                                                 [6]int
	infloor                                                [6]int
	addon                                                  [3]int
	flag                                                   [7]bool
	comment, ownerName                                     string
	legionID                                               int
	emblemVersion                                          int16
	emblemBgcolor                                          int
}

// callPutHouseField shells out to the SP with the canonical 42-arg
// signature in NCSoft order.
func callPutHouseField(t *testing.T, ctx context.Context, p *Pool, r hfRow) int {
	t.Helper()
	var affected int
	err := p.CallSPRow(ctx, "aion_puthousefield",
		r.id, r.addrID, r.buildingNameID, r.ownerID,
		r.ownerType, r.ownerRace, r.state, r.permission, r.commentState,
		r.roof, r.outwall, r.frame, r.door, r.garden, r.fence,
		r.inwall[0], r.inwall[1], r.inwall[2], r.inwall[3], r.inwall[4], r.inwall[5],
		r.infloor[0], r.infloor[1], r.infloor[2], r.infloor[3], r.infloor[4], r.infloor[5],
		r.addon[0], r.addon[1], r.addon[2],
		r.flag[0], r.flag[1], r.flag[2], r.flag[3], r.flag[4], r.flag[5], r.flag[6],
		r.comment, r.ownerName,
		r.legionID, r.emblemVersion, r.emblemBgcolor,
	).Scan(&affected)
	if err != nil {
		t.Fatalf("aion_puthousefield: %v", err)
	}
	return affected
}

func callSetHouseField(t *testing.T, ctx context.Context, p *Pool, r hfRow) int {
	t.Helper()
	var affected int
	err := p.CallSPRow(ctx, "aion_sethousefield",
		r.id, r.addrID, r.buildingNameID, r.ownerID,
		r.ownerType, r.ownerRace, r.state, r.permission, r.commentState,
		r.roof, r.outwall, r.frame, r.door, r.garden, r.fence,
		r.inwall[0], r.inwall[1], r.inwall[2], r.inwall[3], r.inwall[4], r.inwall[5],
		r.infloor[0], r.infloor[1], r.infloor[2], r.infloor[3], r.infloor[4], r.infloor[5],
		r.addon[0], r.addon[1], r.addon[2],
		r.flag[0], r.flag[1], r.flag[2], r.flag[3], r.flag[4], r.flag[5], r.flag[6],
		r.comment, r.ownerName,
		r.legionID, r.emblemVersion, r.emblemBgcolor,
	).Scan(&affected)
	if err != nil {
		t.Fatalf("aion_sethousefield: %v", err)
	}
	return affected
}

func houseFieldCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM house_field WHERE id BETWEEN 9650041 AND 9650099`); err != nil {
		t.Fatalf("houseFieldCleanup house_field: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9650080 AND 9650099`); err != nil {
		t.Fatalf("houseFieldCleanup user_data: %v", err)
	}
}

func TestHouseField(t *testing.T) {
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

	houseFieldCleanup(t, ctx, pool)
	t.Cleanup(func() { houseFieldCleanup(t, context.Background(), pool) })

	// Seed a user_data row whose name will be picked up by SetHouseField's
	// owner_name override branch. The hfOwnerOrphan char_id is intentionally
	// NOT seeded — exercises the "no canonical name" branch.
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data (char_id, name, account_id) VALUES ($1, $2, $3)
		 ON CONFLICT (char_id) DO UPDATE SET name = EXCLUDED.name`,
		hfOwnerCanon, "CanonName", 0); err != nil {
		t.Fatalf("seed user_data canon: %v", err)
	}

	t.Run("Put inserts row, returns 1; payload round-trips", func(t *testing.T) {
		r := hfRow{
			id: hfIDBasic, addrID: 100001, buildingNameID: 200001, ownerID: hfOwnerCanon,
			ownerType: 0, ownerRace: 0, state: 1, permission: 2, commentState: 1,
			roof: 11, outwall: 12, frame: 13, door: 14, garden: 15, fence: 16,
			inwall:  [6]int{21, 22, 23, 24, 25, 26},
			infloor: [6]int{31, 32, 33, 34, 35, 36},
			addon:   [3]int{41, 42, 43},
			flag:    [7]bool{true, false, true, false, true, false, true},
			comment: "hello", ownerName: "supplied",
			legionID: 7777, emblemVersion: 9, emblemBgcolor: 0xFF00AA,
		}
		if got := callPutHouseField(t, ctx, pool, r); got != 1 {
			t.Fatalf("Put basic affected: got %d want 1", got)
		}

		// Verify decoration columns round-trip.
		var (
			roof, outwall, frame                                     int
			inwall1, infloor3, addon2                                int
			flag1, flag2                                             bool
			comment, ownerName                                       string
			legionID                                                 int
			emblemVersion                                            int16
			emblemBgcolor                                            int
		)
		err := pool.Inner().QueryRow(ctx,
			`SELECT roof, outwall, frame, inwall1, infloor3, addon2,
			        flag1, flag2, comment, owner_name,
			        legion_id, emblem_version, emblem_bgcolor
			   FROM house_field WHERE id=$1`,
			r.id).Scan(&roof, &outwall, &frame, &inwall1, &infloor3, &addon2,
			&flag1, &flag2, &comment, &ownerName,
			&legionID, &emblemVersion, &emblemBgcolor)
		if err != nil {
			t.Fatalf("verify Put: %v", err)
		}
		if roof != 11 || outwall != 12 || frame != 13 ||
			inwall1 != 21 || infloor3 != 33 || addon2 != 42 {
			t.Fatalf("decoration round-trip mismatch: roof=%d outwall=%d frame=%d in1=%d if3=%d ad2=%d",
				roof, outwall, frame, inwall1, infloor3, addon2)
		}
		if !flag1 || flag2 {
			t.Fatalf("flag round-trip: flag1=%v flag2=%v want true/false", flag1, flag2)
		}
		if comment != "hello" || ownerName != "supplied" {
			t.Fatalf("text round-trip: comment=%q owner_name=%q want hello/supplied",
				comment, ownerName)
		}
		// Pin: legion_id / emblem_version / emblem_bgcolor are DROPPED
		// by Put (NCSoft "useless param") — must be at column DEFAULT 0.
		if legionID != 0 || emblemVersion != 0 || emblemBgcolor != 0 {
			t.Fatalf("Put must NOT write legion_id/emblem_*: got %d/%d/%d, want 0/0/0 (NCSoft pin)",
				legionID, emblemVersion, emblemBgcolor)
		}
	})

	t.Run("Put on duplicate id → 0 affected (ON CONFLICT DO NOTHING)", func(t *testing.T) {
		r := hfRow{id: hfIDDup, addrID: 100002, buildingNameID: 200002, ownerID: 0,
			comment: "first"}
		if got := callPutHouseField(t, ctx, pool, r); got != 1 {
			t.Fatalf("first Put: got %d want 1", got)
		}

		// Second Put with the same id but different payload.
		r2 := r
		r2.comment = "second"
		if got := callPutHouseField(t, ctx, pool, r2); got != 0 {
			t.Fatalf("dup Put: got %d want 0", got)
		}

		// Verify the original payload was preserved (DO NOTHING semantics).
		var comment string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT comment FROM house_field WHERE id=$1`, r.id).
			Scan(&comment); err != nil {
			t.Fatalf("verify dup: %v", err)
		}
		if comment != "first" {
			t.Fatalf("dup comment: got %q want first (original payload preserved)", comment)
		}
	})

	t.Run("Set overrides owner_name from user_data.name when present", func(t *testing.T) {
		// Put first with arbitrary owner_name.
		r := hfRow{id: hfIDOverride, addrID: 100003, buildingNameID: 200003,
			ownerID: hfOwnerCanon, ownerName: "should-be-overridden",
			comment: "ov-comment",
			legionID: 8888, emblemVersion: 5, emblemBgcolor: 0x123456}
		if got := callPutHouseField(t, ctx, pool, r); got != 1 {
			t.Fatalf("Put before Set: got %d want 1", got)
		}

		// Set with another bogus owner_name; the override branch should
		// pick up "CanonName" from user_data.name.
		r.ownerName = "still-bogus"
		r.comment = "set-applied"
		if got := callSetHouseField(t, ctx, pool, r); got != 1 {
			t.Fatalf("Set affected: got %d want 1", got)
		}

		var ownerName, comment string
		var legionID int
		var emblemVersion int16
		var emblemBgcolor int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT owner_name, comment, legion_id, emblem_version, emblem_bgcolor
			   FROM house_field WHERE id=$1`, r.id).
			Scan(&ownerName, &comment, &legionID, &emblemVersion, &emblemBgcolor); err != nil {
			t.Fatalf("verify Set override: %v", err)
		}
		if ownerName != "CanonName" {
			t.Fatalf("owner_name override: got %q want CanonName (NCSoft user_data.USER_ID pin)",
				ownerName)
		}
		if comment != "set-applied" {
			t.Fatalf("comment after Set: got %q want set-applied", comment)
		}
		// Pin: Set DOES write legion_id / emblem_*.
		if legionID != 8888 || emblemVersion != 5 || emblemBgcolor != 0x123456 {
			t.Fatalf("Set must write legion_id/emblem_*: got %d/%d/0x%X want 8888/5/0x123456",
				legionID, emblemVersion, emblemBgcolor)
		}
	})

	t.Run("Set keeps supplied owner_name when no user_data row", func(t *testing.T) {
		// Put with an owner_id that has NO user_data row.
		r := hfRow{id: hfIDNoOvr, addrID: 100004, buildingNameID: 200004,
			ownerID: hfOwnerOrphan, ownerName: "supplied-keep",
			comment: "no-canon"}
		if got := callPutHouseField(t, ctx, pool, r); got != 1 {
			t.Fatalf("Put orphan: got %d want 1", got)
		}

		// Set with a different supplied name; absent user_data row →
		// our SP keeps the supplied parameter.
		r.ownerName = "still-supplied"
		if got := callSetHouseField(t, ctx, pool, r); got != 1 {
			t.Fatalf("Set orphan: got %d want 1", got)
		}

		var ownerName string
		if err := pool.Inner().QueryRow(ctx,
			`SELECT owner_name FROM house_field WHERE id=$1`, r.id).
			Scan(&ownerName); err != nil {
			t.Fatalf("verify orphan: %v", err)
		}
		if ownerName != "still-supplied" {
			t.Fatalf("orphan owner_name: got %q want still-supplied (no canonical fallback pin)",
				ownerName)
		}
	})

	t.Run("Set on missing id → 0 affected", func(t *testing.T) {
		r := hfRow{id: hfIDMissing, addrID: 100099, buildingNameID: 200099, ownerID: 0,
			ownerName: "ghost", comment: "nope"}
		if got := callSetHouseField(t, ctx, pool, r); got != 0 {
			t.Fatalf("Set missing: got %d want 0", got)
		}
	})

	t.Run("Remove on existing row → 1, row gone", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_removehousefield", int(hfIDBasic)).
			Scan(&affected); err != nil {
			t.Fatalf("Remove: %v", err)
		}
		if affected != 1 {
			t.Fatalf("Remove affected: got %d want 1", affected)
		}

		var n int
		if err := pool.Inner().QueryRow(ctx,
			`SELECT COUNT(*) FROM house_field WHERE id=$1`, hfIDBasic).
			Scan(&n); err != nil {
			t.Fatalf("verify Remove: %v", err)
		}
		if n != 0 {
			t.Fatalf("post-Remove count: got %d want 0", n)
		}
	})

	t.Run("Remove on missing id → 0, no error", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_removehousefield", int(hfIDMissing)).
			Scan(&affected); err != nil {
			t.Fatalf("Remove missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("Remove missing affected: got %d want 0", affected)
		}
	})
}
