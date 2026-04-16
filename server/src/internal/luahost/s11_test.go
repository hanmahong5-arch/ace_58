// Package luahost — Phase S-11 regression tests.
//
// Covers the PvP participation gate + Abyss-point kill-reward system:
//   - pvp global table + faction constants
//   - pvp.get_faction for players and NPCs
//   - pvp.same_faction across Elyos/Asmodian/NPC matrix
//   - pvp.can_damage gate (self, safe_zone, cross-faction, same-faction unflagged,
//     same-faction duel, PvE)
//   - pvp.toggle_flag flips the "pvp_flag" ECS stat
//   - pvp.kill_ap level-diff clamping formula
//   - pvp.award_kill_points cross-faction / same-faction / PvE branches
//   - CM_PVP_FLAG_TOGGLE (0xB8) handler is registered on the dispatcher
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s11ScriptsDir points at server/scripts from this package's working dir.
var s11ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS11Bridge builds a fresh ECS world + Bridge + Lua state with all scripts
// loaded. Mirrors the helper style used by newS10Bridge to keep test wiring
// uniform across phases.
func newS11Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s11ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s11 loadScripts: %v", err)
	}
	return b, L, world, sender
}

// spawnPvpPlayer creates a PlayerComp entity with faction + level set and
// returns the entity id. Used by most can_damage / award tests.
func spawnPvpPlayer(t *testing.T, world *ecs.World,
	gw uint64, charID float64, name string, faction, level float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "faction", faction)
	world.SetStat(eid, "level", level)
	world.SetStat(eid, "pvp_flag", 0)
	world.SetStat(eid, "safe_zone", 0)
	world.SetStat(eid, "dead", 0)
	return eid
}

// spawnPvpNpc creates an NPC entity (NpcComp only, no PlayerComp) with a
// level stat so the damage gate can inspect it.
func spawnPvpNpc(t *testing.T, world *ecs.World, templateID int32, level float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetNpc(eid, &ecs.NpcComp{TemplateID: templateID})
	world.SetStat(eid, "level", level)
	world.SetStat(eid, "pvp_flag", 0)
	world.SetStat(eid, "safe_zone", 0)
	return eid
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpLibLoaded — pvp global exists and exposes all public symbols.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpLibLoaded(t *testing.T) {
	_, L, _, _ := newS11Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("pvp").(*lua.LTable)
	if !ok {
		t.Fatalf("expected pvp to be a table, got %T", L.GetGlobal("pvp"))
	}

	for _, fn := range []string{
		"get_faction", "is_flagged", "same_faction", "can_damage",
		"toggle_flag", "kill_ap", "award_kill_points",
	} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected pvp.%s to be a function, got %T",
				fn, L.GetField(tbl, fn))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpFactionConstants — ELYOS=0, ASMODIAN=1, NPC=-1.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpFactionConstants(t *testing.T) {
	_, L, _, _ := newS11Bridge(t)
	defer L.Close()

	tbl := L.GetGlobal("pvp").(*lua.LTable)
	checks := map[string]lua.LNumber{
		"FACTION_ELYOS":    0,
		"FACTION_ASMODIAN": 1,
		"FACTION_NPC":      -1,
	}
	for field, want := range checks {
		if v := L.GetField(tbl, field); v != want {
			t.Errorf("pvp.%s: want %v, got %v", field, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpGetFaction_PlayerElyos — Elyos player entity returns FACTION_ELYOS.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpGetFaction_PlayerElyos(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	e := spawnPvpPlayer(t, world, 1101, 11001, "Elia", 0, 50)
	L.SetGlobal("EID", lua.LNumber(float64(e)))

	if err := L.DoString(`_s11_f = pvp.get_faction(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_f"); v != lua.LNumber(0) {
		t.Errorf("want Elyos faction=0, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpGetFaction_NpcReturnsNpcConstant — entity without PlayerComp → NPC.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpGetFaction_NpcReturnsNpcConstant(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	npc := spawnPvpNpc(t, world, 200001, 50)
	L.SetGlobal("NID", lua.LNumber(float64(npc)))

	if err := L.DoString(`_s11_f = pvp.get_faction(NID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_f"); v != lua.LNumber(-1) {
		t.Errorf("want NPC faction=-1, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpSameFaction_True — two Elyos players share a faction.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpSameFaction_True(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1201, 12001, "A", 0, 50)
	b := spawnPvpPlayer(t, world, 1202, 12002, "B", 0, 50)
	L.SetGlobal("A", lua.LNumber(float64(a)))
	L.SetGlobal("B", lua.LNumber(float64(b)))

	if err := L.DoString(`_s11_sf = pvp.same_faction(A, B)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_sf"); v != lua.LTrue {
		t.Errorf("want same_faction=true for two Elyos, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpSameFaction_DifferentFactions — Elyos vs Asmodian → false.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpSameFaction_DifferentFactions(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1301, 13001, "ElyA", 0, 50)
	b := spawnPvpPlayer(t, world, 1302, 13002, "AsmB", 1, 50)
	L.SetGlobal("A", lua.LNumber(float64(a)))
	L.SetGlobal("B", lua.LNumber(float64(b)))

	if err := L.DoString(`_s11_sf = pvp.same_faction(A, B)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_sf"); v != lua.LFalse {
		t.Errorf("want same_faction=false cross-faction, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpSameFaction_NpcAlwaysFalse — NPC is never "same faction" as a player.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpSameFaction_NpcAlwaysFalse(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	p := spawnPvpPlayer(t, world, 1401, 14001, "P", 0, 50)
	n := spawnPvpNpc(t, world, 200002, 50)
	L.SetGlobal("P", lua.LNumber(float64(p)))
	L.SetGlobal("N", lua.LNumber(float64(n)))

	chunk := `
_s11_pn = pvp.same_faction(P, N)
_s11_np = pvp.same_faction(N, P)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_pn"); v != lua.LFalse {
		t.Errorf("want same_faction(player, npc)=false, got %v", v)
	}
	if v := L.GetGlobal("_s11_np"); v != lua.LFalse {
		t.Errorf("want same_faction(npc, player)=false, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpCanDamage_CrossFactionAllowed — Elyos attacks Asmodian → ok=true.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpCanDamage_CrossFactionAllowed(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1501, 15001, "Ely", 0, 50)
	b := spawnPvpPlayer(t, world, 1502, 15002, "Asm", 1, 50)
	L.SetGlobal("A", lua.LNumber(float64(a)))
	L.SetGlobal("B", lua.LNumber(float64(b)))

	if err := L.DoString(`_s11_ok, _s11_reason = pvp.can_damage(A, B)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_ok"); v != lua.LTrue {
		t.Errorf("want cross-faction ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s11_reason"))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpCanDamage_SameFactionUnflaggedBlocked — Elyos vs Elyos, no flag → blocked.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpCanDamage_SameFactionUnflaggedBlocked(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1601, 16001, "A1", 0, 50)
	b := spawnPvpPlayer(t, world, 1602, 16002, "A2", 0, 50)
	L.SetGlobal("A", lua.LNumber(float64(a)))
	L.SetGlobal("B", lua.LNumber(float64(b)))

	if err := L.DoString(`_s11_ok, _s11_reason = pvp.can_damage(A, B)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_ok"); v != lua.LFalse {
		t.Errorf("want same-faction unflagged ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s11_reason"); v != lua.LString("same_faction_unflagged") {
		t.Errorf("want reason=same_faction_unflagged, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpCanDamage_SameFactionDuel — both Elyos with pvp_flag=1 → ok=true.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpCanDamage_SameFactionDuel(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1701, 17001, "Duel1", 0, 50)
	b := spawnPvpPlayer(t, world, 1702, 17002, "Duel2", 0, 50)
	world.SetStat(a, "pvp_flag", 1)
	world.SetStat(b, "pvp_flag", 1)
	L.SetGlobal("A", lua.LNumber(float64(a)))
	L.SetGlobal("B", lua.LNumber(float64(b)))

	if err := L.DoString(`_s11_ok, _s11_reason = pvp.can_damage(A, B)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_ok"); v != lua.LTrue {
		t.Errorf("want duel ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s11_reason"))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpCanDamage_Self — self-damage is forbidden with reason "self".
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpCanDamage_Self(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1801, 18001, "Solo", 0, 50)
	L.SetGlobal("A", lua.LNumber(float64(a)))

	if err := L.DoString(`_s11_ok, _s11_reason = pvp.can_damage(A, A)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_ok"); v != lua.LFalse {
		t.Errorf("want self ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s11_reason"); v != lua.LString("self") {
		t.Errorf("want reason=self, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpCanDamage_SafeZone — target inside a safe-zone is untouchable.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpCanDamage_SafeZone(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	a := spawnPvpPlayer(t, world, 1901, 19001, "Att", 0, 50)
	b := spawnPvpPlayer(t, world, 1902, 19002, "SafeTgt", 1, 50)
	world.SetStat(b, "safe_zone", 1)
	L.SetGlobal("A", lua.LNumber(float64(a)))
	L.SetGlobal("B", lua.LNumber(float64(b)))

	if err := L.DoString(`_s11_ok, _s11_reason = pvp.can_damage(A, B)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_ok"); v != lua.LFalse {
		t.Errorf("want safe-zone ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s11_reason"); v != lua.LString("safe_zone") {
		t.Errorf("want reason=safe_zone, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpCanDamage_NpcTarget — player attacking NPC is always allowed (PvE).
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpCanDamage_NpcTarget(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	p := spawnPvpPlayer(t, world, 2001, 20001, "Hero", 0, 50)
	n := spawnPvpNpc(t, world, 200010, 50)
	L.SetGlobal("P", lua.LNumber(float64(p)))
	L.SetGlobal("N", lua.LNumber(float64(n)))

	if err := L.DoString(`_s11_ok, _s11_reason = pvp.can_damage(P, N)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_ok"); v != lua.LTrue {
		t.Errorf("want PvE ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s11_reason"))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpToggleFlag — two toggles flip the stat 0→1→0.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpToggleFlag(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	e := spawnPvpPlayer(t, world, 2101, 21001, "Flagger", 0, 50)
	L.SetGlobal("E", lua.LNumber(float64(e)))

	// First toggle: 0 → 1.
	if err := L.DoString(`_s11_t1 = pvp.toggle_flag(E)`); err != nil {
		t.Fatalf("toggle1 DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_t1"); v != lua.LTrue {
		t.Errorf("want first toggle -> true, got %v", v)
	}
	if f, _ := world.GetStat(e, "pvp_flag"); f != 1 {
		t.Errorf("want pvp_flag stat=1 after first toggle, got %v", f)
	}

	// Second toggle: 1 → 0.
	if err := L.DoString(`_s11_t2 = pvp.toggle_flag(E)`); err != nil {
		t.Fatalf("toggle2 DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_t2"); v != lua.LFalse {
		t.Errorf("want second toggle -> false, got %v", v)
	}
	if f, _ := world.GetStat(e, "pvp_flag"); f != 0 {
		t.Errorf("want pvp_flag stat=0 after second toggle, got %v", f)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpKillApFormula — verifies base, positive diff, negative clamp, and
// max clamp of kill_ap(killer_lvl, victim_lvl).
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpKillApFormula(t *testing.T) {
	_, L, _, _ := newS11Bridge(t)
	defer L.Close()

	chunk := `
_s11_even  = pvp.kill_ap(50, 50)   -- 100 base, no diff
_s11_hi    = pvp.kill_ap(50, 60)   -- +10 diff * 10 = 200
_s11_lo    = pvp.kill_ap(60, 50)   -- -10 diff clamped to MIN=10
_s11_max   = pvp.kill_ap(1, 99)    -- clamp to MAX=500
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	cases := map[string]lua.LNumber{
		"_s11_even": 100,
		"_s11_hi":   200,
		"_s11_lo":   10,
		"_s11_max":  500,
	}
	for g, want := range cases {
		if v := L.GetGlobal(g); v != want {
			t.Errorf("%s: want %v, got %v", g, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpAwardKillPoints_CrossFactionRewards — Elyos lv50 kills Asmo lv50:
// returns 100 and increases the killer's "abyss_points" ECS stat by 100.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpAwardKillPoints_CrossFactionRewards(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	killer := spawnPvpPlayer(t, world, 2201, 22001, "Killer", 0, 50)
	victim := spawnPvpPlayer(t, world, 2202, 22002, "Victim", 1, 50)
	world.SetStat(killer, "abyss_points", 0)

	L.SetGlobal("K", lua.LNumber(float64(killer)))
	L.SetGlobal("V", lua.LNumber(float64(victim)))

	if err := L.DoString(`_s11_awarded = pvp.award_kill_points(K, V)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_awarded"); v != lua.LNumber(100) {
		t.Errorf("want awarded=100, got %v", v)
	}

	// ECS cache must reflect the kill reward.
	ap, _ := world.GetStat(killer, "abyss_points")
	if ap != 100 {
		t.Errorf("want killer abyss_points=100 after award, got %v", ap)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpAwardKillPoints_SameFactionZero — same faction earns zero AP.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpAwardKillPoints_SameFactionZero(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	killer := spawnPvpPlayer(t, world, 2301, 23001, "ElyK", 0, 50)
	victim := spawnPvpPlayer(t, world, 2302, 23002, "ElyV", 0, 50)
	world.SetStat(killer, "abyss_points", 0)

	L.SetGlobal("K", lua.LNumber(float64(killer)))
	L.SetGlobal("V", lua.LNumber(float64(victim)))

	if err := L.DoString(`_s11_awarded = pvp.award_kill_points(K, V)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_awarded"); v != lua.LNumber(0) {
		t.Errorf("want awarded=0 same-faction, got %v", v)
	}
	ap, _ := world.GetStat(killer, "abyss_points")
	if ap != 0 {
		t.Errorf("want killer abyss_points unchanged=0, got %v", ap)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestPvpAwardKillPoints_PveZero — PvE kills do not feed the Abyss ladder.
// ─────────────────────────────────────────────────────────────────────────────
func TestPvpAwardKillPoints_PveZero(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	killer := spawnPvpPlayer(t, world, 2401, 24001, "Hunter", 0, 50)
	victim := spawnPvpNpc(t, world, 200050, 50)
	world.SetStat(killer, "abyss_points", 0)

	L.SetGlobal("K", lua.LNumber(float64(killer)))
	L.SetGlobal("V", lua.LNumber(float64(victim)))

	if err := L.DoString(`_s11_awarded = pvp.award_kill_points(K, V)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s11_awarded"); v != lua.LNumber(0) {
		t.Errorf("want awarded=0 PvE, got %v", v)
	}
	ap, _ := world.GetStat(killer, "abyss_points")
	if ap != 0 {
		t.Errorf("want killer abyss_points unchanged=0, got %v", ap)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmPvpFlagHandlerRegistered — opcode 0xB8 (CM_PVP_FLAG_TOGGLE) must be
// wired into dispatch_packet. We dispatch a real packet on a spawned player
// entity and assert no Lua error + the ECS stat actually flipped.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmPvpFlagHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS11Bridge(t)
	defer L.Close()

	e := spawnPvpPlayer(t, world, 2501, 25001, "Toggler", 0, 50)
	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(2501))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	// An empty payload is valid: CM_PVP_FLAG_TOGGLE carries no fields.
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xB8), ctx, lua.LString(""))
	if err != nil {
		t.Fatalf("dispatch_packet(0xB8) returned error: %v", err)
	}

	// The handler must have run pvp.toggle_flag → pvp_flag stat now == 1.
	f, _ := world.GetStat(e, "pvp_flag")
	if f != 1 {
		t.Errorf("want pvp_flag=1 after CM_PVP_FLAG_TOGGLE dispatch, got %v", f)
	}
}
