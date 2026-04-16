// Package luahost — Phase S-8 regression tests.
//
// Covers:
//   - dialog.lua global table with register/has/open/select/send_window functions
//   - shop.lua global table with buy/sell/open_window functions
//   - NPC template handlers auto-registered by npc_798001.lua and npc_798002.lua
//   - entity.get_npc_template(entity_id) bridge API (NPC and non-NPC entity)
//   - player.get_kinah / player.add_kinah / player.spend_kinah bridge APIs
//   - shop.buy happy path, no_kinah, not_in_shop error paths
//   - CM_DIALOG_REQUEST (0x6A) and CM_DIALOG_SELECT (0x6B) handler registration
//   - CM_BUY_ITEM (0x6C) and CM_SELL_ITEM (0x6D) handler registration
//   - CM_TELEPORT (0x6E) handler registration
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s8ScriptsDir points to the Lua scripts directory from the test's working dir.
var s8ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS8Bridge creates an ECS World and a Bridge with mock DB/Sender.
func newS8Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World) {
	t.Helper()
	world := ecs.NewWorld()
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockSender{}}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s8ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s8 loadScripts: %v", err)
	}
	return b, L, world
}

// requireFn asserts that field `name` in table `tbl` is a *lua.LFunction.
func requireFn(t *testing.T, L *lua.LState, tbl *lua.LTable, name string) {
	t.Helper()
	if _, ok := L.GetField(tbl, name).(*lua.LFunction); !ok {
		t.Errorf("expected %s to be a function, got %T", name, L.GetField(tbl, name))
	}
}

// TestDialogLibLoaded verifies dialog global is a table exposing all expected functions.
func TestDialogLibLoaded(t *testing.T) {
	_, L, _ := newS8Bridge(t)
	defer L.Close()

	// dialog must be a table.
	tbl, ok := L.GetGlobal("dialog").(*lua.LTable)
	if !ok {
		t.Fatalf("expected dialog to be a table, got %T", L.GetGlobal("dialog"))
	}

	// All five public functions must exist.
	for _, fn := range []string{"register", "has", "open", "select", "send_window"} {
		requireFn(t, L, tbl, fn)
	}
}

// TestShopLibLoaded verifies shop global is a table exposing all expected functions.
func TestShopLibLoaded(t *testing.T) {
	_, L, _ := newS8Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("shop").(*lua.LTable)
	if !ok {
		t.Fatalf("expected shop to be a table, got %T", L.GetGlobal("shop"))
	}

	for _, fn := range []string{"buy", "sell", "open_window"} {
		requireFn(t, L, tbl, fn)
	}
}

// TestNpcTemplatesRegistered verifies that after loading all scripts,
// dialog.has(798001) and dialog.has(798002) both return true — meaning the
// example NPC scripts registered their handlers.
func TestNpcTemplatesRegistered(t *testing.T) {
	_, L, _ := newS8Bridge(t)
	defer L.Close()

	// dialog.has must return true for both example NPC templates.
	chunk := `
_s8_has_798001 = dialog.has(798001)
_s8_has_798002 = dialog.has(798002)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_has_798001"); v != lua.LTrue {
		t.Errorf("expected dialog.has(798001)==true, got %v", v)
	}
	if v := L.GetGlobal("_s8_has_798002"); v != lua.LTrue {
		t.Errorf("expected dialog.has(798002)==true, got %v", v)
	}
}

// TestGetNpcTemplate verifies entity.get_npc_template returns the correct
// template ID for an NPC entity and 0 for a non-NPC entity.
func TestGetNpcTemplate(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	// Spawn an NPC entity with TemplateID 798001.
	npcEnt := world.NewEntity()
	world.SetNpc(npcEnt, &ecs.NpcComp{TemplateID: 798001})
	world.SetPosition(npcEnt, &ecs.PositionComp{X: 0, Y: 0, Z: 0})

	// Spawn a plain player entity (no NpcComp).
	playerEnt := world.NewEntity()
	world.SetPlayer(playerEnt, &ecs.PlayerComp{GatewaySeqID: 1})

	L.SetGlobal("_s8_npc_eid", lua.LNumber(float64(npcEnt)))
	L.SetGlobal("_s8_player_eid", lua.LNumber(float64(playerEnt)))

	chunk := `
_s8_tmpl_npc    = entity.get_npc_template(_s8_npc_eid)
_s8_tmpl_player = entity.get_npc_template(_s8_player_eid)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_tmpl_npc"); v != lua.LNumber(798001) {
		t.Errorf("expected get_npc_template(npc)==798001, got %v", v)
	}
	if v := L.GetGlobal("_s8_tmpl_player"); v != lua.LNumber(0) {
		t.Errorf("expected get_npc_template(player)==0, got %v", v)
	}
}

// TestKinahSpendSufficient verifies spend_kinah returns true and deducts the
// correct amount when the player has sufficient balance.
func TestKinahSpendSufficient(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 100})
	world.SetStat(eid, "kinah", 1000)

	chunk := `_s8_spend_ok = player.spend_kinah(100, 300)`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_spend_ok"); v != lua.LTrue {
		t.Errorf("expected spend_kinah(300)==true with balance=1000, got %v", v)
	}

	// Remaining balance must be 700.
	bal, _ := world.GetStat(eid, "kinah")
	if bal != 700 {
		t.Errorf("expected balance=700 after spending 300, got %v", bal)
	}
}

// TestKinahSpendInsufficient verifies spend_kinah returns false and leaves
// the balance unchanged when the player does not have enough kinah.
func TestKinahSpendInsufficient(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 101})
	world.SetStat(eid, "kinah", 100)

	chunk := `_s8_spend_insufficient = player.spend_kinah(101, 500)`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_spend_insufficient"); v != lua.LFalse {
		t.Errorf("expected spend_kinah(500)==false with balance=100, got %v", v)
	}

	// Balance must be unchanged.
	bal, _ := world.GetStat(eid, "kinah")
	if bal != 100 {
		t.Errorf("expected balance=100 (unchanged), got %v", bal)
	}
}

// TestKinahAddThenGet verifies add_kinah and get_kinah round-trip correctly.
func TestKinahAddThenGet(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 102})
	// kinah stat intentionally not set (zero-value, unset)

	chunk := `
_s8_add_ok  = player.add_kinah(102, 250)
_s8_get_bal = player.get_kinah(102)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_add_ok"); v != lua.LTrue {
		t.Errorf("expected add_kinah==true, got %v", v)
	}
	if v := L.GetGlobal("_s8_get_bal"); v != lua.LNumber(250) {
		t.Errorf("expected get_kinah==250, got %v", v)
	}
}

// TestShopBuyHappyPath verifies that shop.buy deducts the correct kinah and
// returns true when the player has sufficient balance and the item is in stock.
func TestShopBuyHappyPath(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 200})
	world.SetStat(eid, "kinah", 10000)

	// Inject entity_id so the Lua chunk can reference it.
	L.SetGlobal("_s8_eid", lua.LNumber(float64(eid)))

	chunk := `
local ctx = { entity_id = _s8_eid, gateway_seq_id = 200 }
local SHOP = { [50001] = 200 }
_s8_buy_ok = shop.buy(ctx, SHOP, 50001, 3)
_s8_buy_bal = player.get_kinah(200)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	// shop.buy returns only ok (true) on success (reason is nil, not pushed).
	if v := L.GetGlobal("_s8_buy_ok"); v != lua.LTrue {
		t.Errorf("expected shop.buy==true, got %v", v)
	}
	// 10000 - 3*200 = 9400
	if v := L.GetGlobal("_s8_buy_bal"); v != lua.LNumber(9400) {
		t.Errorf("expected balance=9400 after buy, got %v", v)
	}
}

// TestShopBuyNoKinah verifies that shop.buy returns false + "no_kinah" when
// the player cannot afford the purchase, and balance remains unchanged.
func TestShopBuyNoKinah(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 201})
	world.SetStat(eid, "kinah", 100)

	L.SetGlobal("_s8_nk_eid", lua.LNumber(float64(eid)))

	chunk := `
local ctx = { entity_id = _s8_nk_eid, gateway_seq_id = 201 }
local SHOP = { [50001] = 200 }
_s8_nk_ok, _s8_nk_reason = shop.buy(ctx, SHOP, 50001, 3)
_s8_nk_bal = player.get_kinah(201)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_nk_ok"); v != lua.LFalse {
		t.Errorf("expected shop.buy==false, got %v", v)
	}
	if v := L.GetGlobal("_s8_nk_reason"); v != lua.LString("no_kinah") {
		t.Errorf("expected reason==\"no_kinah\", got %v", v)
	}
	// Balance must be unchanged.
	if v := L.GetGlobal("_s8_nk_bal"); v != lua.LNumber(100) {
		t.Errorf("expected balance=100 (unchanged), got %v", v)
	}
}

// TestShopBuyNotInShop verifies that shop.buy returns false + "not_in_shop"
// when the requested item_id is not listed in the shop table.
func TestShopBuyNotInShop(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: 202})
	world.SetStat(eid, "kinah", 5000)

	L.SetGlobal("_s8_ns_eid", lua.LNumber(float64(eid)))

	chunk := `
local ctx = { entity_id = _s8_ns_eid, gateway_seq_id = 202 }
local SHOP = { [50001] = 200 }
_s8_ns_ok, _s8_ns_reason = shop.buy(ctx, SHOP, 99999, 1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s8_ns_ok"); v != lua.LFalse {
		t.Errorf("expected shop.buy==false for missing item, got %v", v)
	}
	if v := L.GetGlobal("_s8_ns_reason"); v != lua.LString("not_in_shop") {
		t.Errorf("expected reason==\"not_in_shop\", got %v", v)
	}
}

// dispatchNoUnknownError is a helper that dispatches opcode via Lua dispatch_packet
// and asserts there is no unhandled error (unknown opcode produces a Lua error).
func dispatchNoUnknownError(t *testing.T, L *lua.LState, opcode lua.LNumber, ctx *lua.LTable) {
	t.Helper()

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	// Use an empty bytes reader as the payload.  Handlers may short-circuit on
	// empty data; that is acceptable — what we assert is no "no handler" error.
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

// TestCmDialogHandlersRegistered verifies that 0x6A (CM_DIALOG_REQUEST) and
// 0x6B (CM_DIALOG_SELECT) are both registered (no "no handler" error).
func TestCmDialogHandlersRegistered(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 300})
	world.SetStat(e, "dead", 0)

	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(300))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	for _, op := range []lua.LNumber{0x6A, 0x6B} {
		dispatchNoUnknownError(t, L, op, ctx)
	}
}

// TestCmShopHandlersRegistered verifies that 0x6C (CM_BUY_ITEM) and
// 0x6D (CM_SELL_ITEM) are both registered.
func TestCmShopHandlersRegistered(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 301})
	world.SetStat(e, "dead", 0)

	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(301))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	for _, op := range []lua.LNumber{0x6C, 0x6D} {
		dispatchNoUnknownError(t, L, op, ctx)
	}
}

// TestCmTeleportHandlerRegistered verifies that 0x6E (CM_TELEPORT) is registered.
func TestCmTeleportHandlerRegistered(t *testing.T) {
	_, L, world := newS8Bridge(t)
	defer L.Close()

	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 302})
	world.SetStat(e, "dead", 0)

	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(302))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	dispatchNoUnknownError(t, L, 0x6E, ctx)
}
