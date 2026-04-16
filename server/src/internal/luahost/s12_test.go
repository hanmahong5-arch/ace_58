// Package luahost — Phase S-12 regression tests.
//
// Covers the Equipment System + Item Templates subsystem:
//   - items registry global (items.get / items.is_equippable / items.register)
//   - equipment global constants (SLOT_* + SLOT_COUNT + is_valid_slot)
//   - equipment.equip happy path + four failure reasons
//     (unknown_item | not_equippable | bad_slot | low_level)
//   - equipment.unequip happy path + "empty" / "bad_slot" failures
//   - auto-replace semantics: re-equipping into the same slot swaps items
//   - multi-slot stat aggregation via equipment.recompute
//   - damage_calc.physical consumes the aggregated equip_attack stat
//   - CM_EQUIP_ITEM (0xBB) and CM_UNEQUIP_ITEM (0xBC) dispatcher wiring
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s12ScriptsDir points at server/scripts from this package's working dir.
var s12ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS12Bridge builds a fresh ECS world + Bridge + Lua state with all scripts
// loaded. Mirrors newS11Bridge so every S-12 test starts from a clean slate.
func newS12Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s12ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s12 loadScripts: %v", err)
	}
	return b, L, world, sender
}

// spawnS12Player creates a PlayerComp entity with a level set and the usual
// safe/dead/pvp stats zeroed. Equipment tests always operate on a player
// entity because equipment.equip reads the "level" stat for req-level checks.
func spawnS12Player(t *testing.T, world *ecs.World,
	gw uint64, charID float64, name string, level float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "faction", 0)
	world.SetStat(eid, "level", level)
	world.SetStat(eid, "pvp_flag", 0)
	world.SetStat(eid, "safe_zone", 0)
	world.SetStat(eid, "dead", 0)
	return eid
}

// ─────────────────────────────────────────────────────────────────────────────
// TestItemsLibLoaded — items global is a table exposing get/is_equippable/register.
// ─────────────────────────────────────────────────────────────────────────────
func TestItemsLibLoaded(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("items").(*lua.LTable)
	if !ok {
		t.Fatalf("expected items to be a table, got %T", L.GetGlobal("items"))
	}
	for _, fn := range []string{"get", "is_equippable", "register"} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected items.%s to be a function, got %T",
				fn, L.GetField(tbl, fn))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestItemsGet_KnownItem — items.get(100001) returns a template with the
// exact Wooden Sword fields from the seeded catalogue.
// ─────────────────────────────────────────────────────────────────────────────
func TestItemsGet_KnownItem(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	chunk := `
_s12_t   = items.get(100001)
_s12_nm  = _s12_t.name
_s12_sl  = _s12_t.slot
_s12_at  = _s12_t.attack
_s12_rl  = _s12_t.required_level
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_nm"); v != lua.LString("Wooden Sword") {
		t.Errorf("want name=Wooden Sword, got %v", v)
	}
	if v := L.GetGlobal("_s12_sl"); v != lua.LNumber(1) {
		t.Errorf("want slot=1 (MAIN_HAND), got %v", v)
	}
	if v := L.GetGlobal("_s12_at"); v != lua.LNumber(30) {
		t.Errorf("want attack=30, got %v", v)
	}
	if v := L.GetGlobal("_s12_rl"); v != lua.LNumber(1) {
		t.Errorf("want required_level=1, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestItemsGet_UnknownReturnsNil — items.get for an unseeded id returns nil.
// ─────────────────────────────────────────────────────────────────────────────
func TestItemsGet_UnknownReturnsNil(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	// Push a bool flag indicating "result was nil" because Lua nil cannot be
	// transported through SetGlobal.
	if err := L.DoString(`_s12_is_nil = (items.get(999999) == nil)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_is_nil"); v != lua.LTrue {
		t.Errorf("want items.get(999999)==nil, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestItemsIsEquippable_Weapon — Wooden Sword (slot=1) is equippable.
// ─────────────────────────────────────────────────────────────────────────────
func TestItemsIsEquippable_Weapon(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	if err := L.DoString(`_s12_eq = items.is_equippable(100001)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_eq"); v != lua.LTrue {
		t.Errorf("want Wooden Sword equippable, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestItemsIsEquippable_Potion — Healing Potion (slot=0) is NOT equippable.
// ─────────────────────────────────────────────────────────────────────────────
func TestItemsIsEquippable_Potion(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	if err := L.DoString(`_s12_eq = items.is_equippable(200001)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_eq"); v != lua.LFalse {
		t.Errorf("want Healing Potion not equippable, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentLibLoaded — equipment global is a table exposing the public API.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentLibLoaded(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("equipment").(*lua.LTable)
	if !ok {
		t.Fatalf("expected equipment to be a table, got %T", L.GetGlobal("equipment"))
	}
	for _, fn := range []string{
		"equip", "unequip", "get_slot", "get_equipped",
		"recompute", "is_valid_slot",
	} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected equipment.%s to be a function, got %T",
				fn, L.GetField(tbl, fn))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentSlotConstants — MAIN_HAND=1, WINGS=15, SLOT_COUNT=15.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentSlotConstants(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	tbl := L.GetGlobal("equipment").(*lua.LTable)
	checks := map[string]lua.LNumber{
		"SLOT_MAIN_HAND": 1,
		"SLOT_WINGS":     15,
		"SLOT_COUNT":     15,
	}
	for field, want := range checks {
		if v := L.GetField(tbl, field); v != want {
			t.Errorf("equipment.%s: want %v, got %v", field, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentIsValidSlot — range [1,15] true, out-of-range false.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentIsValidSlot(t *testing.T) {
	_, L, _, _ := newS12Bridge(t)
	defer L.Close()

	chunk := `
_s12_v1   = equipment.is_valid_slot(1)
_s12_v15  = equipment.is_valid_slot(15)
_s12_v0   = equipment.is_valid_slot(0)
_s12_v16  = equipment.is_valid_slot(16)
_s12_vneg = equipment.is_valid_slot(-1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	cases := map[string]lua.LValue{
		"_s12_v1":   lua.LTrue,
		"_s12_v15":  lua.LTrue,
		"_s12_v0":   lua.LFalse,
		"_s12_v16":  lua.LFalse,
		"_s12_vneg": lua.LFalse,
	}
	for g, want := range cases {
		if v := L.GetGlobal(g); v != want {
			t.Errorf("%s: want %v, got %v", g, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentEquip_HappyPath — level-10 player equips the Wooden Sword:
// ok=true, slot=1, slot stat holds 100001, equip_attack == 30.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentEquip_HappyPath(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3101, 31001, "Hero", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s12_ok, _s12_slot = equipment.equip(E, 100001)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LTrue {
		t.Errorf("want ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s12_slot"))
	}
	if v := L.GetGlobal("_s12_slot"); v != lua.LNumber(1) {
		t.Errorf("want slot=1, got %v", v)
	}
	if got := int(mustStat(t, world, eid, "equip_slot_1")); got != 100001 {
		t.Errorf("want equip_slot_1=100001, got %d", got)
	}
	if got := mustStat(t, world, eid, "equip_attack"); got != 30 {
		t.Errorf("want equip_attack=30, got %v", got)
	}
	// get_slot cross-check via Lua.
	if err := L.DoString(`_s12_gs = equipment.get_slot(E, 1)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_gs"); v != lua.LNumber(100001) {
		t.Errorf("want get_slot(E,1)=100001, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentEquip_UnknownItem — unregistered item id returns unknown_item.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentEquip_UnknownItem(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3201, 32001, "NoItem", 50)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s12_ok, _s12_r = equipment.equip(E, 999999)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LFalse {
		t.Errorf("want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s12_r"); v != lua.LString("unknown_item") {
		t.Errorf("want reason=unknown_item, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentEquip_NotEquippable — Healing Potion has slot=0 → not_equippable.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentEquip_NotEquippable(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3301, 33001, "Drinker", 50)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s12_ok, _s12_r = equipment.equip(E, 200001)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LFalse {
		t.Errorf("want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s12_r"); v != lua.LString("not_equippable") {
		t.Errorf("want reason=not_equippable, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentEquip_LowLevel — level 1 player cannot equip Iron Sword (req=10).
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentEquip_LowLevel(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3401, 34001, "Newbie", 1)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s12_ok, _s12_r = equipment.equip(E, 100002)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LFalse {
		t.Errorf("want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s12_r"); v != lua.LString("low_level") {
		t.Errorf("want reason=low_level, got %v", v)
	}
	// Slot must remain empty — contract is that a failed equip writes nothing.
	// An unset stat is equivalent to 0 in this subsystem, so either
	// "not present" or explicit 0 both satisfy the invariant.
	if v, ok := world.GetStat(eid, "equip_slot_1"); ok && v != 0 {
		t.Errorf("want equip_slot_1 still empty, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentEquip_ReplacesExisting — equipping a second weapon into the
// same slot discards the first: slot 1 holds 100002 and equip_attack is 80
// (NOT 30+80=110 which would indicate buggy accumulation).
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentEquip_ReplacesExisting(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3501, 35001, "Swapper", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	chunk := `
_s12_ok1, _ = equipment.equip(E, 100001)  -- Wooden Sword, atk=30
_s12_ok2, _ = equipment.equip(E, 100002)  -- Iron Sword,   atk=80
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok1"); v != lua.LTrue {
		t.Errorf("first equip: want ok=true, got %v", v)
	}
	if v := L.GetGlobal("_s12_ok2"); v != lua.LTrue {
		t.Errorf("second equip: want ok=true, got %v", v)
	}
	if got := int(mustStat(t, world, eid, "equip_slot_1")); got != 100002 {
		t.Errorf("want slot 1 = 100002 (Iron Sword), got %d", got)
	}
	if got := mustStat(t, world, eid, "equip_attack"); got != 80 {
		t.Errorf("want equip_attack=80 (no accumulation), got %v", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentUnequip_HappyPath — after equipping, unequip returns ok=true
// and the returned item_id, clears the slot, and resets equip_attack to 0.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentUnequip_HappyPath(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3601, 36001, "Remover", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	chunk := `
equipment.equip(E, 100001)
_s12_ok, _s12_iid = equipment.unequip(E, 1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LTrue {
		t.Errorf("want ok=true, got %v", v)
	}
	if v := L.GetGlobal("_s12_iid"); v != lua.LNumber(100001) {
		t.Errorf("want returned item_id=100001, got %v", v)
	}
	if got := int(mustStat(t, world, eid, "equip_slot_1")); got != 0 {
		t.Errorf("want slot 1 cleared, got %d", got)
	}
	if got := mustStat(t, world, eid, "equip_attack"); got != 0 {
		t.Errorf("want equip_attack=0 after unequip, got %v", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentUnequip_Empty — unequipping an already-empty slot returns
// false, "empty".
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentUnequip_Empty(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3701, 37001, "Empty", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s12_ok, _s12_r = equipment.unequip(E, 1)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LFalse {
		t.Errorf("want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s12_r"); v != lua.LString("empty") {
		t.Errorf("want reason=empty, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentUnequip_BadSlot — slot out of range returns false, "bad_slot".
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentUnequip_BadSlot(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3801, 38001, "Bad", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s12_ok, _s12_r = equipment.unequip(E, 99)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s12_ok"); v != lua.LFalse {
		t.Errorf("want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s12_r"); v != lua.LString("bad_slot") {
		t.Errorf("want reason=bad_slot, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestEquipmentStatAggregation_Multi — equip five items across distinct slots
// and verify equip_attack / equip_defense / equip_hp_bonus sum correctly.
//
// Loadout (level 10 player):
//   100001 Wooden Sword    MAIN_HAND   atk=30  def=0   hp=0
//   100003 Wooden Shield   SUB_HAND    atk=0   def=20  hp=0
//   100004 Leather Helmet  HELMET      atk=0   def=10  hp=20
//   100005 Leather Tunic   CHEST       atk=0   def=25  hp=50
//   100008 Copper Ring     RING_L      atk=5   def=0   hp=10
// Expected: equip_attack=35, equip_defense=55, equip_hp_bonus=80.
// ─────────────────────────────────────────────────────────────────────────────
func TestEquipmentStatAggregation_Multi(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 3901, 39001, "Geared", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))

	chunk := `
equipment.equip(E, 100001)  -- Wooden Sword  → MAIN_HAND
equipment.equip(E, 100003)  -- Wooden Shield → SUB_HAND
equipment.equip(E, 100004)  -- Helmet        → HELMET
equipment.equip(E, 100005)  -- Tunic         → CHEST
equipment.equip(E, 100008)  -- Copper Ring   → RING_L
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if got := mustStat(t, world, eid, "equip_attack"); got != 35 {
		t.Errorf("want equip_attack=35, got %v", got)
	}
	if got := mustStat(t, world, eid, "equip_defense"); got != 55 {
		t.Errorf("want equip_defense=55, got %v", got)
	}
	if got := mustStat(t, world, eid, "equip_hp_bonus"); got != 80 {
		t.Errorf("want equip_hp_bonus=80, got %v", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestDamageCalcUsesEquipAttack — an attacker with equip_attack=100 must
// produce damage well above the no-equip baseline. With level 1 vs level 1:
//   base = 10 + 1*5 = 15  (no-equip)   → non-crit ≤ 30, capped well under 100
//   base = 15 + 100 = 115 (with equip) → non-crit 115, crit 230
// We set a fixed random seed and assert damage > 100 strictly, which is
// impossible without the equip_attack bonus.
// ─────────────────────────────────────────────────────────────────────────────
func TestDamageCalcUsesEquipAttack(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	attacker := spawnS12Player(t, world, 4001, 40001, "Striker", 1)
	target := spawnS12Player(t, world, 4002, 40002, "Dummy", 1)
	// Give the target plenty of hp so deal_damage does not clamp to 0.
	world.SetStat(target, "hp", 10000)
	world.SetStat(target, "max_hp", 10000)
	// Directly inject equip_attack — this is the exact stat written by
	// equipment.recompute in the real flow.
	world.SetStat(attacker, "equip_attack", 100)

	L.SetGlobal("A", lua.LNumber(float64(attacker)))
	L.SetGlobal("T", lua.LNumber(float64(target)))

	// Seed deterministically so the crit roll is reproducible across runs.
	chunk := `
math.randomseed(42)
_s12_dmg = damage_calc.physical(A, T)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	dmg, ok := L.GetGlobal("_s12_dmg").(lua.LNumber)
	if !ok {
		t.Fatalf("want damage_calc.physical to return a number, got %T",
			L.GetGlobal("_s12_dmg"))
	}
	if float64(dmg) <= 100 {
		t.Errorf("want damage > 100 (equip_attack=100 bonus must apply), got %v", dmg)
	}

	// Sanity: a pristine attacker with no equip_attack cannot exceed 100 at lv1.
	attacker2 := spawnS12Player(t, world, 4003, 40003, "Naked", 1)
	target2 := spawnS12Player(t, world, 4004, 40004, "Dummy2", 1)
	world.SetStat(target2, "hp", 10000)
	world.SetStat(target2, "max_hp", 10000)
	L.SetGlobal("A2", lua.LNumber(float64(attacker2)))
	L.SetGlobal("T2", lua.LNumber(float64(target2)))
	if err := L.DoString(`
math.randomseed(42)
_s12_dmg2 = damage_calc.physical(A2, T2)
`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	dmg2, _ := L.GetGlobal("_s12_dmg2").(lua.LNumber)
	if float64(dmg2) > 100 {
		t.Errorf("sanity: no-equip damage should be <=100 at lv1, got %v", dmg2)
	}
	if float64(dmg) <= float64(dmg2) {
		t.Errorf("want equipped damage (%v) > naked damage (%v)", dmg, dmg2)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmEquipHandlerRegistered — dispatching CM_EQUIP_ITEM (0xBB) populates
// the slot and recomputes bonuses just like a direct equipment.equip call.
// Payload layout: int32 item_id (LE) + byte slot_hint.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmEquipHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 4101, 41001, "Dispatcher", 10)
	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(4101))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	// 100001 = 0x000186A1 → LE [A1, 86, 01, 00], then slot_hint byte = 0.
	payload := string([]byte{0xA1, 0x86, 0x01, 0x00, 0x00})

	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xBB), ctx, lua.LString(payload))
	if err != nil {
		t.Fatalf("dispatch_packet(0xBB) returned error: %v", err)
	}

	// Side-effect assertion: slot 1 must now hold the Wooden Sword.
	if got := int(mustStat(t, world, eid, "equip_slot_1")); got != 100001 {
		t.Errorf("want equip_slot_1=100001 after CM_EQUIP_ITEM, got %d", got)
	}
	if got := mustStat(t, world, eid, "equip_attack"); got != 30 {
		t.Errorf("want equip_attack=30 after CM_EQUIP_ITEM, got %v", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmUnequipHandlerRegistered — dispatching CM_UNEQUIP_ITEM (0xBC) after
// a prior equip clears the slot back to zero. Payload layout: byte slot.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmUnequipHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS12Bridge(t)
	defer L.Close()

	eid := spawnS12Player(t, world, 4201, 42001, "Unequipper", 10)
	L.SetGlobal("E", lua.LNumber(float64(eid)))
	L.SetGlobal("current_tick", lua.LNumber(1))

	// Pre-equip via the library so there is something to remove.
	if err := L.DoString(`equipment.equip(E, 100001)`); err != nil {
		t.Fatalf("pre-equip failed: %v", err)
	}

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(4201))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	// CM_UNEQUIP_ITEM payload = one byte carrying the slot index.
	payload := string([]byte{0x01})

	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xBC), ctx, lua.LString(payload))
	if err != nil {
		t.Fatalf("dispatch_packet(0xBC) returned error: %v", err)
	}

	// Side-effect assertion: slot 1 must now be empty and bonuses cleared.
	if got := int(mustStat(t, world, eid, "equip_slot_1")); got != 0 {
		t.Errorf("want equip_slot_1=0 after CM_UNEQUIP_ITEM, got %d", got)
	}
	if got := mustStat(t, world, eid, "equip_attack"); got != 0 {
		t.Errorf("want equip_attack=0 after CM_UNEQUIP_ITEM, got %v", got)
	}
}

// mustStat reads an ECS stat and fails the test if it is missing. Centralised
// so each assertion stays a single readable line.
func mustStat(t *testing.T, world *ecs.World, eid ecs.Entity, key string) float64 {
	t.Helper()
	v, ok := world.GetStat(eid, key)
	if !ok {
		t.Fatalf("missing stat %q on entity %d", key, eid)
	}
	return v
}
