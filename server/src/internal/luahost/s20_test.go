// Package luahost — Sprint 2 STORY-9 regression tests.
//
// Covers DEFAULT_BASE_SPEED ECS stat injection on flight state transitions
// (5lw#5):
//
//   - On spawn, no "base_speed" stat is set; anti_cheat.check_move falls back
//     to the lib's DEFAULT_BASE_SPEED constant (11.0 m/s) — direct
//     entity.get_stat returns 0 (Go binding's missing-stat sentinel) and the
//     lib's > 0 guard rejects that.
//   - flight.set_state(eid, FLY=2) writes ECS "base_speed" = 15.0.
//   - flight.set_state(eid, GROUND=0) resets ECS "base_speed" back to 11.0
//     (also exercised after a FLY → GROUND round trip).
//
// These tests pin the contract that anti_cheat speed-hack judgement reads
// the per-state authoritative cap, NOT a hardcoded 11.0.
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s20ScriptsDir mirrors the s9/s14/s19 conventions: scripts dir relative to
// this package's working directory.
var s20ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS20Bridge wires a fresh ECS world + Bridge + Lua state with all scripts
// loaded.  Identical pattern to s9/s14/s19 — no JobQueue needed because
// flight.set_state is purely synchronous.
func newS20Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World) {
	t.Helper()
	world := ecs.NewWorld()
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s20ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s20 loadScripts: %v", err)
	}
	return b, L, world
}

// spawnS20Player creates a vanilla player entity without setting base_speed,
// so the test exercises the missing-stat fallback path.
func spawnS20Player(t *testing.T, world *ecs.World, gw uint64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: "S20"})
	world.SetStat(eid, "fp", 1000) // enough for takeoff if any test wants it
	world.SetStat(eid, "dead", 0)
	return eid
}

// ─────────────────────────────────────────────────────────────────────────────
// TestSpeedDefault_NoStat — fresh entity has no base_speed stat. The Go
// binding returns 0 for the missing key; anti_cheat.check_move's > 0 guard
// must fall back to DEFAULT_BASE_SPEED (11.0). We assert the *Go-side* ECS
// view directly (no stat present) since the lib's internal fallback is
// already covered by s19/s14 anti_cheat tests.
// ─────────────────────────────────────────────────────────────────────────────
func TestSpeedDefault_NoStat(t *testing.T) {
	_, L, world := newS20Bridge(t)
	defer L.Close()

	eid := spawnS20Player(t, world, 2000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Lua reads via entity.get_stat — missing stat returns 0 by binding contract.
	if err := L.DoString(`_s20_default = entity.get_stat(EID, "base_speed")`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_s20_default"); v != lua.LNumber(0) {
		t.Errorf("missing base_speed stat must read as 0 (Go binding default), got %v", v)
	}

	// And the Go-side ECS view: no entry.
	if v, ok := world.GetStat(eid, "base_speed"); ok {
		t.Errorf("expected no base_speed stat on fresh spawn, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestSpeedFly_SetStateInjects15 — flight.set_state(eid, FLY) must write
// ECS "base_speed" = 15.0 so anti_cheat.check_move can read the authoritative
// flight cap.
// ─────────────────────────────────────────────────────────────────────────────
func TestSpeedFly_SetStateInjects15(t *testing.T) {
	_, L, world := newS20Bridge(t)
	defer L.Close()

	eid := spawnS20Player(t, world, 2001)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`flight.set_state(EID, flight.STATE_FLY)`); err != nil {
		t.Fatalf("set_state(FLY) DoString: %v", err)
	}

	// Lua side.
	if err := L.DoString(`_s20_fly = entity.get_stat(EID, "base_speed")`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_s20_fly"); v != lua.LNumber(15) {
		t.Errorf("base_speed after set_state(FLY): want 15, got %v", v)
	}

	// Go-side ECS confirmation.
	if v, ok := world.GetStat(eid, "base_speed"); !ok || v != 15.0 {
		t.Errorf("ECS base_speed after set_state(FLY): want 15.0 (present), got %v ok=%v", v, ok)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestSpeedGround_SetStateResets11 — round trip GROUND→FLY→GROUND must end
// with ECS "base_speed" = 11.0; this is the post-landing speed-cap reset.
// ─────────────────────────────────────────────────────────────────────────────
func TestSpeedGround_SetStateResets11(t *testing.T) {
	_, L, world := newS20Bridge(t)
	defer L.Close()

	eid := spawnS20Player(t, world, 2002)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Take off → speed should be 15.
	if err := L.DoString(`flight.set_state(EID, flight.STATE_FLY)`); err != nil {
		t.Fatalf("set_state(FLY) DoString: %v", err)
	}
	if v, ok := world.GetStat(eid, "base_speed"); !ok || v != 15.0 {
		t.Fatalf("precondition: FLY must inject 15.0, got %v ok=%v", v, ok)
	}

	// Land → speed should reset to 11.
	if err := L.DoString(`flight.set_state(EID, flight.STATE_GROUND)`); err != nil {
		t.Fatalf("set_state(GROUND) DoString: %v", err)
	}

	if err := L.DoString(`_s20_grnd = entity.get_stat(EID, "base_speed")`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_s20_grnd"); v != lua.LNumber(11) {
		t.Errorf("base_speed after set_state(GROUND): want 11, got %v", v)
	}
	if v, ok := world.GetStat(eid, "base_speed"); !ok || v != 11.0 {
		t.Errorf("ECS base_speed after set_state(GROUND): want 11.0, got %v ok=%v", v, ok)
	}
}
