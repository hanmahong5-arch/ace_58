// Package luahost — Phase S-9 regression tests.
//
// Covers:
//   - flight.lua global table with get_state/is_airborne/set_state/takeoff/land/
//     glide_start/glide_end/drain functions and STATE_* constants
//   - flight.takeoff: dead / no_fp / already guards; success sets state=FLY in ECS
//   - flight.land: resets state to GROUND
//   - flight.glide_start: transitions GROUND→GLIDE; rejects already-airborne
//   - flight.drain: FLY drains 1.0/tick; GLIDE drains 0.25/tick; force-lands at 0 FP
//   - flight.drain: returns false when already on ground (no-op)
//   - NPC template 798003 (Flight Master) auto-registered via dialog.register
//   - CM_FLIGHT_TOGGLE (0x71), CM_GLIDE_START (0x72), CM_GLIDE_END (0x73),
//     CM_FLIGHT_PATH_SELECT (0x75) handlers registered without "unknown opcode"
package luahost

import (
	"math"
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s9ScriptsDir points to the Lua scripts directory from the test's working dir.
var s9ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS9Bridge creates an ECS World and a Bridge with mock DB/Sender, then loads
// all Lua scripts.  Mirrors the setup pattern used by s7_test.go / s8_test.go.
func newS9Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World) {
	t.Helper()
	world := ecs.NewWorld()
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s9ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s9 loadScripts: %v", err)
	}
	return b, L, world
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightLibLoaded — flight global is a table exposing all public symbols.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightLibLoaded(t *testing.T) {
	_, L, _ := newS9Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("flight").(*lua.LTable)
	if !ok {
		t.Fatalf("expected flight to be a table, got %T", L.GetGlobal("flight"))
	}

	// All public functions must exist.
	for _, fn := range []string{
		"get_state", "is_airborne", "set_state",
		"takeoff", "land", "glide_start", "glide_end", "drain",
	} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected flight.%s to be a function, got %T", fn, L.GetField(tbl, fn))
		}
	}

	// Numeric state constants must match the spec.
	if v := L.GetField(tbl, "STATE_GROUND"); v != lua.LNumber(0) {
		t.Errorf("flight.STATE_GROUND: want 0, got %v", v)
	}
	if v := L.GetField(tbl, "STATE_GLIDE"); v != lua.LNumber(1) {
		t.Errorf("flight.STATE_GLIDE: want 1, got %v", v)
	}
	if v := L.GetField(tbl, "STATE_FLY"); v != lua.LNumber(2) {
		t.Errorf("flight.STATE_FLY: want 2, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightStateDefaultGround — new entity starts in GROUND state (0).
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightStateDefaultGround(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 100})
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s9_default_state = flight.get_state(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_default_state"); v != lua.LNumber(0) {
		t.Errorf("want default state=0, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightTakeoffSufficientFP — fp>=50 lets takeoff succeed; ECS state=FLY.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightTakeoffSufficientFP(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 101})
	world.SetStat(eid, "fp", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s9_to_ok, _s9_to_reason = flight.takeoff(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_to_ok"); v != lua.LTrue {
		t.Errorf("takeoff with fp=1000: want ok=true (reason=%v)", L.GetGlobal("_s9_to_reason"))
	}

	// State must be FLY (2) both from Lua and from Go ECS.
	if err := L.DoString(`_s9_to_state = flight.get_state(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s9_to_state"); v != lua.LNumber(2) {
		t.Errorf("want state=2 after takeoff, got %v", v)
	}

	ecsStat, ok := world.GetStat(eid, "flight_state")
	if !ok || ecsStat != 2 {
		t.Errorf("ECS flight_state: want 2, got %v (ok=%v)", ecsStat, ok)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightTakeoffInsufficientFP — fp<50 is rejected with "no_fp".
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightTakeoffInsufficientFP(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 102})
	world.SetStat(eid, "fp", 10)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s9_nofp_ok, _s9_nofp_reason = flight.takeoff(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_nofp_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for fp=10, got %v", v)
	}
	if v := L.GetGlobal("_s9_nofp_reason"); v != lua.LString("no_fp") {
		t.Errorf("want reason=no_fp, got %v", v)
	}

	// State must remain GROUND.
	ecsStat, _ := world.GetStat(eid, "flight_state")
	if ecsStat != 0 {
		t.Errorf("ECS flight_state: want 0, got %v", ecsStat)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightTakeoffDead — dead entity is rejected with "dead".
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightTakeoffDead(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 103})
	world.SetStat(eid, "dead", 1)
	world.SetStat(eid, "fp", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_s9_dead_ok, _s9_dead_reason = flight.takeoff(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_dead_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for dead entity, got %v", v)
	}
	if v := L.GetGlobal("_s9_dead_reason"); v != lua.LString("dead") {
		t.Errorf("want reason=dead, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightTakeoffAlreadyFlying — second takeoff call returns "already".
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightTakeoffAlreadyFlying(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 104})
	world.SetStat(eid, "fp", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// First takeoff must succeed.
	if err := L.DoString(`_s9_first_ok = flight.takeoff(EID)`); err != nil {
		t.Fatalf("first takeoff DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s9_first_ok"); v != lua.LTrue {
		t.Fatalf("first takeoff: want ok=true, got %v", v)
	}

	// Second takeoff must return already.
	if err := L.DoString(`_s9_dup_ok, _s9_dup_reason = flight.takeoff(EID)`); err != nil {
		t.Fatalf("second takeoff DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s9_dup_ok"); v != lua.LFalse {
		t.Errorf("second takeoff: want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s9_dup_reason"); v != lua.LString("already") {
		t.Errorf("second takeoff: want reason=already, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightLand — land after takeoff returns state to GROUND.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightLand(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 105})
	world.SetStat(eid, "fp", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`
flight.takeoff(EID)
_s9_land_ok = flight.land(EID)
_s9_land_state = flight.get_state(EID)
`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_land_ok"); v != lua.LTrue {
		t.Errorf("land: want ok=true, got %v", v)
	}
	if v := L.GetGlobal("_s9_land_state"); v != lua.LNumber(0) {
		t.Errorf("land: want state=0, got %v", v)
	}

	ecsStat, _ := world.GetStat(eid, "flight_state")
	if ecsStat != 0 {
		t.Errorf("ECS flight_state after land: want 0, got %v", ecsStat)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightGlideStart — glide_start transitions GROUND → GLIDE (state=1).
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightGlideStart(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 106})
	world.SetStat(eid, "fp", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`
_s9_gs_ok, _s9_gs_reason = flight.glide_start(EID)
_s9_gs_state = flight.get_state(EID)
`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_gs_ok"); v != lua.LTrue {
		t.Errorf("glide_start: want ok=true (reason=%v)", L.GetGlobal("_s9_gs_reason"))
	}
	if v := L.GetGlobal("_s9_gs_state"); v != lua.LNumber(1) {
		t.Errorf("glide_start: want state=1, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightGlideStartAlreadyAirborne — can't glide when already airborne.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightGlideStartAlreadyAirborne(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 107})
	world.SetStat(eid, "fp", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Takeoff first to put entity into FLY state.
	if err := L.DoString(`flight.takeoff(EID)`); err != nil {
		t.Fatalf("takeoff DoString failed: %v", err)
	}

	if err := L.DoString(`_s9_aa_ok, _s9_aa_reason = flight.glide_start(EID)`); err != nil {
		t.Fatalf("glide_start DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_aa_ok"); v != lua.LFalse {
		t.Errorf("glide_start when airborne: want ok=false, got %v", v)
	}
	if v := L.GetGlobal("_s9_aa_reason"); v != lua.LString("already_airborne") {
		t.Errorf("glide_start when airborne: want reason=already_airborne, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightDrainFly — FLY state drains 1.0 FP per tick; returns true.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightDrainFly(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 108})
	world.SetStat(eid, "fp", 100)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Set FLY state directly (bypasses takeoff FP check, which is fine for drain tests).
	if err := L.DoString(`flight.set_state(EID, flight.STATE_FLY)`); err != nil {
		t.Fatalf("set_state DoString failed: %v", err)
	}

	// Drain 10 ticks.
	chunk := `
_s9_drain_fly_last = true
for _i = 1, 10 do
    _s9_drain_fly_last = flight.drain(EID)
end
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("drain loop DoString failed: %v", err)
	}

	// After 10 ticks at 1.0/tick: 100 - 10 = 90.
	fp, _ := world.GetStat(eid, "fp")
	if math.Abs(fp-90) > 0.001 {
		t.Errorf("FLY drain 10 ticks: want fp=90, got %v", fp)
	}

	// Should still be airborne.
	if v := L.GetGlobal("_s9_drain_fly_last"); v != lua.LTrue {
		t.Errorf("10 drain ticks at fp=100: want still airborne (true), got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightDrainForceLand — drain to 0 FP triggers force-land.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightDrainForceLand(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 109})
	world.SetStat(eid, "fp", 3)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`flight.set_state(EID, flight.STATE_FLY)`); err != nil {
		t.Fatalf("set_state DoString failed: %v", err)
	}

	// Tick 1: fp = 3 - 1 = 2, still airborne.
	if err := L.DoString(`_s9_fl_r1 = flight.drain(EID)`); err != nil {
		t.Fatalf("drain tick 1 failed: %v", err)
	}
	if v := L.GetGlobal("_s9_fl_r1"); v != lua.LTrue {
		t.Errorf("tick1 with fp=3: want true, got %v", v)
	}

	// Tick 2: fp = 2 - 1 = 1, still airborne.
	if err := L.DoString(`_s9_fl_r2 = flight.drain(EID)`); err != nil {
		t.Fatalf("drain tick 2 failed: %v", err)
	}
	if v := L.GetGlobal("_s9_fl_r2"); v != lua.LTrue {
		t.Errorf("tick2 with fp=2: want true, got %v", v)
	}

	// Tick 3: fp = 1 - 1 = 0 → force-land; must return false.
	if err := L.DoString(`_s9_fl_r3 = flight.drain(EID)`); err != nil {
		t.Fatalf("drain tick 3 failed: %v", err)
	}
	if v := L.GetGlobal("_s9_fl_r3"); v != lua.LFalse {
		t.Errorf("tick3 exhausts FP: want false (force-land), got %v", v)
	}

	// ECS state must be GROUND and fp == 0 after force-land.
	flightSt, _ := world.GetStat(eid, "flight_state")
	if flightSt != 0 {
		t.Errorf("after force-land: want flight_state=0, got %v", flightSt)
	}
	fp, _ := world.GetStat(eid, "fp")
	if fp != 0 {
		t.Errorf("after force-land: want fp=0, got %v", fp)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightDrainGlide — GLIDE state drains 0.25 FP per tick.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightDrainGlide(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 110})
	world.SetStat(eid, "fp", 100)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`flight.set_state(EID, flight.STATE_GLIDE)`); err != nil {
		t.Fatalf("set_state DoString failed: %v", err)
	}

	// 4 drain calls at 0.25/tick: 100 - 1.0 = 99.
	for i := 0; i < 4; i++ {
		if err := L.DoString(`flight.drain(EID)`); err != nil {
			t.Fatalf("glide drain tick %d failed: %v", i+1, err)
		}
	}

	fp, _ := world.GetStat(eid, "fp")
	if math.Abs(fp-99) > 0.001 {
		t.Errorf("GLIDE drain 4 ticks: want fp=99, got %v", fp)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestFlightDrainGround — drain on GROUND state is a no-op and returns false.
// ─────────────────────────────────────────────────────────────────────────────
func TestFlightDrainGround(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 111})
	world.SetStat(eid, "fp", 100)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Default state is GROUND — no set_state needed.
	if err := L.DoString(`_s9_dg_result = flight.drain(EID)`); err != nil {
		t.Fatalf("drain on ground DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_dg_result"); v != lua.LFalse {
		t.Errorf("drain on ground: want false, got %v", v)
	}

	// FP must be unchanged.
	fp, _ := world.GetStat(eid, "fp")
	if math.Abs(fp-100) > 0.001 {
		t.Errorf("drain on ground: fp should be unchanged (100), got %v", fp)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestNpc798003Registered — Flight Master NPC auto-registers via dialog.register.
// ─────────────────────────────────────────────────────────────────────────────
func TestNpc798003Registered(t *testing.T) {
	_, L, _ := newS9Bridge(t)
	defer L.Close()

	if err := L.DoString(`_s9_has_798003 = dialog.has(798003)`); err != nil {
		t.Fatalf("dialog.has DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s9_has_798003"); v != lua.LTrue {
		t.Errorf("expected dialog.has(798003)==true after loadScripts, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmFlightHandlersRegistered — opcodes 0x71–0x73 and 0x75 are all registered.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmFlightHandlersRegistered(t *testing.T) {
	_, L, world := newS9Bridge(t)
	defer L.Close()

	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 200})
	world.SetStat(e, "dead", 0)
	world.SetStat(e, "fp", 500)

	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(200))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	// 0x71 CM_FLIGHT_TOGGLE — no payload needed; handler accesses flight lib.
	for _, op := range []lua.LNumber{0x71, 0x72, 0x73} {
		err := L.CallByParam(lua.P{
			Fn:      dispatchFn,
			NRet:    0,
			Protect: true,
		}, op, ctx, lua.LString(""))
		if err != nil {
			t.Errorf("dispatch_packet(0x%02X) unexpected error: %v", int(op), err)
		}
	}

	// 0x75 CM_FLIGHT_PATH_SELECT — requires a 4-byte int32 payload (dst_id=99, unknown).
	// The handler should log "No active flight master" / "Unknown flight destination"
	// but must not panic or raise "no handler" error.
	buf := make([]byte, 4)
	buf[0] = 99 // dst_id=99 as little-endian int32
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0x75), ctx, lua.LString(string(buf)))
	if err != nil {
		t.Errorf("dispatch_packet(0x75) unexpected error: %v", err)
	}
}
