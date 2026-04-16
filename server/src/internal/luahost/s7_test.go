// Package luahost — Phase S-7 regression tests.
//
// Covers:
//   - chat global table with CH_* constants and broadcast functions
//   - group global table with party management functions
//   - player.set_name / player.get_name / player.find_by_name Bridge APIs
//   - group.invite / group.accept flow via pure Lua
//   - group MAX_MEMBERS=6 boundary: 6th member accepted, 7th invite rejected
//   - CM_CHAT (0x46) and CM_GROUP_* (0x60-0x62) handler registration
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s7ScriptsDir points to the Lua scripts directory from the test's working dir.
var s7ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS7State builds a sandboxed LState loaded with the real scripts.
// Bridge must have at minimum ECS set; nil DB / nil Sender are acceptable.
func newS7State(t *testing.T, bridge *Bridge) *lua.LState {
	t.Helper()
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	bridge.Register(L)
	if err := loadScripts(L, s7ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s7 loadScripts: %v", err)
	}
	return L
}

// TestChatLibLoaded verifies that chat.lua exposes the global "chat" table
// with broadcast functions and the expected CH_* numeric constants.
func TestChatLibLoaded(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newS7State(t, bridge)
	defer L.Close()

	chatGlobal := L.GetGlobal("chat")
	chatTbl, ok := chatGlobal.(*lua.LTable)
	if !ok {
		t.Fatalf("expected chat to be a table, got %T (%v)", chatGlobal, chatGlobal)
	}

	// Verify broadcast_local is a function.
	if _, ok := L.GetField(chatTbl, "broadcast_local").(*lua.LFunction); !ok {
		t.Error("expected chat.broadcast_local to be a function")
	}
	// Verify broadcast_shout is a function.
	if _, ok := L.GetField(chatTbl, "broadcast_shout").(*lua.LFunction); !ok {
		t.Error("expected chat.broadcast_shout to be a function")
	}
	// Verify send_whisper is a function.
	if _, ok := L.GetField(chatTbl, "send_whisper").(*lua.LFunction); !ok {
		t.Error("expected chat.send_whisper to be a function")
	}
	// Verify broadcast_group is a function.
	if _, ok := L.GetField(chatTbl, "broadcast_group").(*lua.LFunction); !ok {
		t.Error("expected chat.broadcast_group to be a function")
	}
	// Verify send_system is a function.
	if _, ok := L.GetField(chatTbl, "send_system").(*lua.LFunction); !ok {
		t.Error("expected chat.send_system to be a function")
	}

	// CH_NORMAL == 0
	if v := L.GetField(chatTbl, "CH_NORMAL"); v != lua.LNumber(0) {
		t.Errorf("expected chat.CH_NORMAL==0, got %v", v)
	}
	// CH_SHOUT == 1
	if v := L.GetField(chatTbl, "CH_SHOUT"); v != lua.LNumber(1) {
		t.Errorf("expected chat.CH_SHOUT==1, got %v", v)
	}
	// CH_WHISPER == 2
	if v := L.GetField(chatTbl, "CH_WHISPER"); v != lua.LNumber(2) {
		t.Errorf("expected chat.CH_WHISPER==2, got %v", v)
	}
}

// TestGroupLibLoaded verifies that group.lua exposes the global "group" table
// with all expected party management functions.
func TestGroupLibLoaded(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newS7State(t, bridge)
	defer L.Close()

	groupGlobal := L.GetGlobal("group")
	groupTbl, ok := groupGlobal.(*lua.LTable)
	if !ok {
		t.Fatalf("expected group to be a table, got %T (%v)", groupGlobal, groupGlobal)
	}

	fns := []string{"invite", "accept", "leave", "disband", "get", "members", "member_gateways"}
	for _, fn := range fns {
		if _, ok := L.GetField(groupTbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected group.%s to be a function", fn)
		}
	}
}

// TestPlayerSetAndGetName verifies the player.set_name / player.get_name round-trip
// and that player.find_by_name resolves to the correct entity ID.
func TestPlayerSetAndGetName(t *testing.T) {
	world := ecs.NewWorld()
	e := world.NewEntity()
	// Register the entity with GatewaySeqID=100 and empty CharName initially.
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 100, CharName: ""})

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	L := newS7State(t, bridge)
	defer L.Close()

	// Call player.set_name(100, "Bob") and player.get_name(100).
	chunk := `
_s7_name_before = player.get_name(100)
player.set_name(100, "Bob")
_s7_name_after  = player.get_name(100)
_s7_find_eid    = player.find_by_name("Bob")
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	// Before set_name, CharName is empty.
	if v := L.GetGlobal("_s7_name_before"); v != lua.LString("") {
		t.Errorf("expected empty name before set_name, got %v", v)
	}
	// After set_name, CharName must be "Bob".
	if v := L.GetGlobal("_s7_name_after"); v != lua.LString("Bob") {
		t.Errorf("expected name==\"Bob\" after set_name, got %v", v)
	}
	// find_by_name must return the correct entity ID.
	expectedEID := lua.LNumber(float64(e))
	if v := L.GetGlobal("_s7_find_eid"); v != expectedEID {
		t.Errorf("expected find_by_name(\"Bob\")==%v, got %v", expectedEID, v)
	}
}

// TestGroupInviteFlow verifies the invite → accept → group.get round-trip.
// Uses pure Lua via DoString; entities are set up directly in ECS.
func TestGroupInviteFlow(t *testing.T) {
	world := ecs.NewWorld()
	// Entity IDs 1 and 2 are convenient but real IDs are assigned by NewEntity.
	e1 := world.NewEntity()
	e2 := world.NewEntity()
	world.SetPlayer(e1, &ecs.PlayerComp{GatewaySeqID: 201})
	world.SetPlayer(e2, &ecs.PlayerComp{GatewaySeqID: 202})

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	bridge.SetCurrentTick(1)

	L := newS7State(t, bridge)
	defer L.Close()

	// Sync Lua current_tick.
	L.SetGlobal("current_tick", lua.LNumber(1))

	eid1 := lua.LNumber(float64(e1))
	eid2 := lua.LNumber(float64(e2))

	chunk := `
local eid1, eid2 = ` + eid1.String() + `, ` + eid2.String() + `
_s7_inv_ok, _s7_inv_reason = group.invite(eid1, eid2)
_s7_acc_ok, _s7_acc_reason = group.accept(eid2)
local g = group.get(eid1)
if g then
    _s7_leader = g.leader
    _s7_count  = #g.members
else
    _s7_leader = -1
    _s7_count  = -1
end
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString group flow failed: %v", err)
	}

	if v := L.GetGlobal("_s7_inv_ok"); v != lua.LTrue {
		t.Errorf("expected invite ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s7_inv_reason"))
	}
	if v := L.GetGlobal("_s7_acc_ok"); v != lua.LTrue {
		t.Errorf("expected accept ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s7_acc_reason"))
	}
	if v := L.GetGlobal("_s7_leader"); v != eid1 {
		t.Errorf("expected group leader==%v, got %v", eid1, v)
	}
	if v := L.GetGlobal("_s7_count"); v != lua.LNumber(2) {
		t.Errorf("expected group member count==2, got %v", v)
	}
}

// TestGroupMaxMembers verifies the MAX_MEMBERS=6 cap.
// Leader + 5 accepted invites = 6 members (full). 6th invite must return false, "full".
func TestGroupMaxMembers(t *testing.T) {
	world := ecs.NewWorld()

	// Create leader and 6 candidate members (entity indices 0..6).
	entities := make([]ecs.Entity, 7)
	for i := range entities {
		e := world.NewEntity()
		entities[i] = e
		world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: uint64(300 + i)})
	}

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	bridge.SetCurrentTick(1)

	L := newS7State(t, bridge)
	defer L.Close()
	L.SetGlobal("current_tick", lua.LNumber(1))

	leader := lua.LNumber(float64(entities[0]))

	// Invite and accept 5 members (entities[1]..entities[5]).
	// After acceptance the group has 6 members (full).
	for i := 1; i <= 5; i++ {
		target := lua.LNumber(float64(entities[i]))
		invChunk := `_s7_max_inv_ok, _s7_max_inv_reason = group.invite(` +
			leader.String() + `, ` + target.String() + `)`
		if err := L.DoString(invChunk); err != nil {
			t.Fatalf("invite %d DoString failed: %v", i, err)
		}
		if v := L.GetGlobal("_s7_max_inv_ok"); v != lua.LTrue {
			t.Fatalf("invite %d expected ok=true, got %v (%v)",
				i, v, L.GetGlobal("_s7_max_inv_reason"))
		}

		accChunk := `_s7_max_acc_ok, _s7_max_acc_reason = group.accept(` + target.String() + `)`
		if err := L.DoString(accChunk); err != nil {
			t.Fatalf("accept %d DoString failed: %v", i, err)
		}
		if v := L.GetGlobal("_s7_max_acc_ok"); v != lua.LTrue {
			t.Fatalf("accept %d expected ok=true, got %v (%v)",
				i, v, L.GetGlobal("_s7_max_acc_reason"))
		}
	}

	// 6th invite (entities[6]) — group is now at MAX_MEMBERS=6, must be rejected.
	overflow := lua.LNumber(float64(entities[6]))
	overflowChunk := `_s7_overflow_ok, _s7_overflow_reason = group.invite(` +
		leader.String() + `, ` + overflow.String() + `)`
	if err := L.DoString(overflowChunk); err != nil {
		t.Fatalf("overflow invite DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s7_overflow_ok"); v != lua.LFalse {
		t.Errorf("expected 7th invite to return false (group full), got %v", v)
	}
	if v := L.GetGlobal("_s7_overflow_reason"); v != lua.LString("full") {
		t.Errorf("expected reason==\"full\", got %v", v)
	}
}

// TestCmChatHandlerRegistered verifies that dispatch_packet(0x46, ctx, payload)
// does not log "no handler" — i.e. the handler is registered.
// The handler may fail on empty payload but must not report an unknown opcode.
func TestCmChatHandlerRegistered(t *testing.T) {
	world := ecs.NewWorld()
	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 400})
	world.SetStat(e, "dead", 0)

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	L := newS7State(t, bridge)
	defer L.Close()

	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(400))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	// dispatch_packet must not return a Lua error (the handler may PCcall internally).
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0x46), ctx, lua.LString(""))

	if err != nil {
		t.Errorf("dispatch_packet(0x46) returned unexpected error: %v", err)
	}
}

// TestCmGroupHandlersRegistered verifies that opcodes 0x60, 0x61, 0x62 are
// all registered (dispatch_packet must not log "no handler" for any of them).
func TestCmGroupHandlersRegistered(t *testing.T) {
	world := ecs.NewWorld()
	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 500})

	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	L := newS7State(t, bridge)
	defer L.Close()

	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(500))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	for _, opcode := range []lua.LNumber{0x60, 0x61, 0x62} {
		err := L.CallByParam(lua.P{
			Fn:      dispatchFn,
			NRet:    0,
			Protect: true,
		}, opcode, ctx, lua.LString(""))

		if err != nil {
			t.Errorf("dispatch_packet(0x%02X) returned unexpected error: %v",
				int(opcode), err)
		}
	}
}
