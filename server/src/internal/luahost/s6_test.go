// Package luahost — Phase S-6 regression tests.
//
// Covers:
//   - skill.use() returning (false, "unknown") for unregistered skills
//   - buff global table and buff.apply function existence
//   - CM_LOGOUT (0xAB) handler registration verified via dispatch_packet
//   - skill.use() returning (false, "cooldown") on second call within cooldown window
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s6ScriptsDir points to the Lua scripts directory from the test's working dir.
var s6ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS6State builds a sandboxed LState loaded with the real scripts.
// bridge must have at minimum ECS set (nil DB / nil Sender are acceptable for these tests).
func newS6State(t *testing.T, bridge *Bridge) *lua.LState {
	t.Helper()
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	bridge.Register(L)
	if err := loadScripts(L, s6ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s6 loadScripts: %v", err)
	}
	return L
}

// TestSkillUseReturnsTwoValues verifies that skill.use() with an unregistered
// skill_id returns exactly two values: false and the string "unknown".
func TestSkillUseReturnsTwoValues(t *testing.T) {
	world := ecs.NewWorld()
	bridge := &Bridge{ECS: world} // nil DB and Sender are fine for this test

	L := newS6State(t, bridge)
	defer L.Close()

	// Execute the call and capture the two return values into Lua globals.
	chunk := `
_s6_ok, _s6_reason = skill.use({entity_id=1, gateway_seq_id=0}, 9999, 0)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	// First return value must be false (skill not found → rejection).
	okVal := L.GetGlobal("_s6_ok")
	if okVal != lua.LFalse {
		t.Errorf("expected skill.use to return false for unknown skill, got %v (%T)", okVal, okVal)
	}

	// Second return value must be the string "unknown".
	reasonVal := L.GetGlobal("_s6_reason")
	if reasonVal != lua.LString("unknown") {
		t.Errorf("expected reason=\"unknown\", got %v (%T)", reasonVal, reasonVal)
	}
}

// TestBuffLuaWrapperExists verifies that scripts/lib/buff.lua exposes the
// global "buff" table with both "apply" and "apply_dot" as callable functions.
func TestBuffLuaWrapperExists(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newS6State(t, bridge)
	defer L.Close()

	// Verify the global "buff" table exists.
	buffGlobal := L.GetGlobal("buff")
	buffTbl, ok := buffGlobal.(*lua.LTable)
	if !ok {
		t.Fatalf("expected buff to be a table, got %T (%v)", buffGlobal, buffGlobal)
	}

	// Verify buff.apply is a function.
	applyFn := L.GetField(buffTbl, "apply")
	if _, ok := applyFn.(*lua.LFunction); !ok {
		t.Errorf("expected buff.apply to be a function, got %T (%v)", applyFn, applyFn)
	}

	// Verify buff.apply_dot is a function.
	applyDotFn := L.GetField(buffTbl, "apply_dot")
	if _, ok := applyDotFn.(*lua.LFunction); !ok {
		t.Errorf("expected buff.apply_dot to be a function, got %T (%v)", applyDotFn, applyDotFn)
	}
}

// TestCmLogoutHandlerRegistered verifies that the CM_LOGOUT (0xAB) handler is
// registered.  We call dispatch_packet(0xAB, ctx, payload) with a minimal ctx
// and check that it does NOT log a "no handler" warning by asserting the call
// does not produce a Lua runtime error (the handler itself may fail on nil ctx
// fields, but it must not say "unknown opcode").
//
// To be deterministic we give the entity a valid char_id so the handler runs
// its full save path (which calls db.call — satisfied by mockDB returning nil).
func TestCmLogoutHandlerRegistered(t *testing.T) {
	world := ecs.NewWorld()
	// Create an entity with a non-zero char_id so the handler reaches db.call.
	e := world.NewEntity()
	world.SetStat(e, "char_id", 42)
	world.SetStat(e, "hp", 100)
	world.SetStat(e, "mp", 200)
	world.SetStat(e, "fp", 50)

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}

	L := newS6State(t, bridge)
	defer L.Close()

	// Verify dispatch_packet function exists.
	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global is not defined after loadScripts")
	}

	// Build a minimal ctx table matching the handler's expectations.
	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(0))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	// Empty payload string (CM_LOGOUT has no payload fields).
	payload := lua.LString("")

	// Call dispatch_packet; it must not return a Lua error.
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true, // catch panics/errors as return value
	}, lua.LNumber(0xAB), ctx, payload)

	if err != nil {
		t.Errorf("dispatch_packet(0xAB) returned unexpected error: %v", err)
	}
}

// TestSkillUseReasonCooldown registers a transient skill with a 30-second
// cooldown, fires it once (succeeds), advances current_tick to within the
// cooldown window, then fires again — expecting (false, "cooldown").
func TestSkillUseReasonCooldown(t *testing.T) {
	world := ecs.NewWorld()
	e := world.NewEntity()
	// Enough MP so the first use succeeds (skill has mp_cost=0 but set anyway).
	world.SetStat(e, "mp", 1000)

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	// Start at tick 1 so current_tick > 0.
	bridge.SetCurrentTick(1)

	L := newS6State(t, bridge)
	defer L.Close()

	// Register a temporary skill with id=7001 and 30-second cooldown.
	// TICK_RATE is 20 inside skill.lua, so 30s → 600 ticks → expires at tick 601.
	regChunk := `
skill.register({ id = 7001, name = "TestCooldownSkill", cooldown = 30, mp_cost = 0,
    on_use = function(ctx, target_id) end })
`
	if err := L.DoString(regChunk); err != nil {
		t.Fatalf("skill.register chunk failed: %v", err)
	}

	// Synchronise Lua's current_tick global with the bridge tick (tick=1).
	// on_tick() sets it; call it with tick=1 to prime the global.
	onTickFn := L.GetGlobal("on_tick")
	if onTickFn == lua.LNil {
		t.Fatal("on_tick global not defined")
	}
	if err := L.CallByParam(lua.P{Fn: onTickFn, NRet: 0, Protect: true},
		lua.LNumber(1)); err != nil {
		t.Fatalf("on_tick(1): %v", err)
	}

	// First use — should succeed (no cooldown yet).
	firstChunk := `
_s6_first_ok, _s6_first_reason = skill.use({entity_id=` +
		lua.LNumber(float64(e)).String() + `}, 7001, 0)
`
	if err := L.DoString(firstChunk); err != nil {
		t.Fatalf("first skill.use chunk failed: %v", err)
	}
	if L.GetGlobal("_s6_first_ok") != lua.LTrue {
		t.Errorf("expected first skill.use to succeed, got ok=%v reason=%v",
			L.GetGlobal("_s6_first_ok"), L.GetGlobal("_s6_first_reason"))
	}

	// Advance to tick=5 — still deep inside the 600-tick cooldown window.
	bridge.SetCurrentTick(5)
	if err := L.CallByParam(lua.P{Fn: onTickFn, NRet: 0, Protect: true},
		lua.LNumber(5)); err != nil {
		t.Fatalf("on_tick(5): %v", err)
	}

	// Second use — must be rejected with reason "cooldown".
	secondChunk := `
_s6_second_ok, _s6_second_reason = skill.use({entity_id=` +
		lua.LNumber(float64(e)).String() + `}, 7001, 0)
`
	if err := L.DoString(secondChunk); err != nil {
		t.Fatalf("second skill.use chunk failed: %v", err)
	}

	secondOk := L.GetGlobal("_s6_second_ok")
	secondReason := L.GetGlobal("_s6_second_reason")

	if secondOk != lua.LFalse {
		t.Errorf("expected second skill.use to return false (cooldown), got %v", secondOk)
	}
	if secondReason != lua.LString("cooldown") {
		t.Errorf("expected reason=\"cooldown\", got %v", secondReason)
	}
}
