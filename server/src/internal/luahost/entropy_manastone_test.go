// Round 4 Track C2 — Entropy v0 manastone-roll determinism / diversity tests.
//
// Asserts the contract of scripts/entropy/manastone_roll.lua:
//
//   1. Determinism: identical (item_uid, item_class, tier, season_seed) tuple
//      always produces an identical 6-tuple of stone_ids.
//   2. Diversity:   1000 distinct (item_uid) inputs produce no duplicate
//      6-tuples (collision rate must be 0 for v0; if non-zero, the LCG
//      seed-mix has degenerated and we'd be shipping identical-feeling
//      "different" swords).
//   3. Pool validity: every non-zero stone_id returned is a member of one
//      of manastone_pool.{common, rare, epic}.
//
// No production code is touched; the Lua scripts are loaded into a fresh
// sandboxed VM the same way scripts_test.go does.

package luahost

import (
	"fmt"
	"testing"

	lua "github.com/yuin/gopher-lua"
)

// callRollManastones invokes entropy.roll_manastones and decodes the
// returned LTable into a Go []int64.
func callRollManastones(t *testing.T, L *lua.LState,
	itemUID int64, itemClass, tier string, seasonSeed int64) []int64 {
	t.Helper()

	entropyTbl, ok := L.GetGlobal("entropy").(*lua.LTable)
	if !ok {
		t.Fatal("global `entropy` is not a table — did manastone_roll.lua load?")
	}
	rollFn := L.GetField(entropyTbl, "roll_manastones")
	if rollFn == lua.LNil {
		t.Fatal("entropy.roll_manastones is not defined")
	}

	if err := L.CallByParam(lua.P{Fn: rollFn, NRet: 1, Protect: true},
		lua.LNumber(float64(itemUID)),
		lua.LString(itemClass),
		lua.LString(tier),
		lua.LNumber(float64(seasonSeed)),
	); err != nil {
		t.Fatalf("entropy.roll_manastones call failed: %v", err)
	}
	ret := L.Get(-1)
	L.Pop(1)

	tbl, ok := ret.(*lua.LTable)
	if !ok {
		t.Fatalf("entropy.roll_manastones returned non-table %T", ret)
	}
	out := make([]int64, 0, 6)
	tbl.ForEach(func(_, v lua.LValue) {
		n, ok := v.(lua.LNumber)
		if !ok {
			t.Fatalf("non-number stone_id in result: %v (%T)", v, v)
		}
		out = append(out, int64(n))
	})
	if len(out) != 6 {
		t.Fatalf("expected 6 slots, got %d", len(out))
	}
	return out
}

// poolMembership builds a set[stone_id] from manastone_pool.{common,rare,epic}
// for fast O(1) validity checks in the diversity test.
func poolMembership(t *testing.T, L *lua.LState) map[int64]bool {
	t.Helper()
	poolTbl, ok := L.GetGlobal("manastone_pool").(*lua.LTable)
	if !ok {
		t.Fatal("global `manastone_pool` is not a table — did manastone_pool.lua load?")
	}
	set := make(map[int64]bool, 256)
	for _, tier := range []string{"common", "rare", "epic"} {
		v := L.GetField(poolTbl, tier)
		arr, ok := v.(*lua.LTable)
		if !ok {
			t.Fatalf("manastone_pool.%s is not a table", tier)
		}
		arr.ForEach(func(_, sv lua.LValue) {
			n, ok := sv.(lua.LNumber)
			if !ok {
				t.Fatalf("non-number in manastone_pool.%s: %v", tier, sv)
			}
			set[int64(n)] = true
		})
	}
	if len(set) == 0 {
		t.Fatal("merged manastone pool is empty")
	}
	return set
}

// TestEntropyManastoneDeterministic — same seed must give same output.
// Three different (uid, season) tuples are each rolled twice; both rolls per
// tuple must match exactly.
func TestEntropyManastoneDeterministic(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	cases := []struct {
		uid, season int64
		class, tier string
	}{
		{uid: 12345, season: 0xC0FFEE, class: "weapon", tier: "rare"},
		{uid: 99999, season: 0xC0FFEE, class: "armor", tier: "common"},
		{uid: 100001, season: 0xDEADBEEF, class: "accessory", tier: "epic"},
	}
	for _, c := range cases {
		a := callRollManastones(t, L, c.uid, c.class, c.tier, c.season)
		b := callRollManastones(t, L, c.uid, c.class, c.tier, c.season)
		for i := 0; i < 6; i++ {
			if a[i] != b[i] {
				t.Errorf("non-deterministic at uid=%d slot=%d: got %d then %d",
					c.uid, i, a[i], b[i])
			}
		}
	}
}

// TestEntropyManastoneDiversity — 1000 distinct UIDs must yield 1000 distinct
// 6-tuples. A single collision means the LCG seed-mix has a degenerate point
// and we'd be shipping identical-feeling "different" swords.
func TestEntropyManastoneDiversity(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const sampleSize = 1000
	const seasonSeed = 0xC0FFEE
	seen := make(map[string]int64, sampleSize)
	for uid := int64(1); uid <= sampleSize; uid++ {
		stones := callRollManastones(t, L, uid, "weapon", "rare", seasonSeed)
		key := fmt.Sprintf("%d,%d,%d,%d,%d,%d",
			stones[0], stones[1], stones[2], stones[3], stones[4], stones[5])
		if prev, dup := seen[key]; dup {
			t.Errorf("collision: uid=%d and uid=%d produced identical 6-tuple %s",
				prev, uid, key)
			return
		}
		seen[key] = uid
	}
	if len(seen) != sampleSize {
		t.Errorf("expected %d unique configs, got %d", sampleSize, len(seen))
	}
}

// TestEntropyManastonePoolValidity — every non-zero stone_id returned across
// 500 random rolls must be a member of the production-mined pool.
func TestEntropyManastonePoolValidity(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	validIDs := poolMembership(t, L)

	classes := []string{"weapon", "armor", "accessory"}
	tiers := []string{"common", "rare", "epic"}
	for uid := int64(1); uid <= 500; uid++ {
		class := classes[uid%int64(len(classes))]
		tier := tiers[uid%int64(len(tiers))]
		// Skip combos that pool config disallows (accessory + non-epic) so the
		// test does not flag legitimate "no allowed pool" -> all-zero results
		// as invalid. We still cover those via the dedicated case below.
		if class == "accessory" && tier != "epic" {
			continue
		}
		stones := callRollManastones(t, L, uid, class, tier, 0xC0FFEE)
		for slot, sid := range stones {
			if sid == 0 {
				continue // empty slots are valid by design
			}
			if !validIDs[sid] {
				t.Errorf("uid=%d %s/%s slot=%d returned stone_id=%d not in pool",
					uid, class, tier, slot, sid)
			}
		}
	}

	// Edge case: accessory + common should yield all zeros (no allowed tier).
	stones := callRollManastones(t, L, 42, "accessory", "common", 0xC0FFEE)
	for slot, sid := range stones {
		if sid != 0 {
			t.Errorf("accessory/common should produce empty slots, slot=%d got stone=%d",
				slot, sid)
		}
	}
}
