// Package luahost — Phase S-15 regression tests.
//
// Covers the Warehouse System MVP (scripts/lib/warehouse.lua +
// handlers/cm_warehouse_{list,deposit,withdraw}.lua + npcs/npc_798004.lua):
//   - warehouse global table with list/deposit/withdraw/open_session/
//     close_session/has_session + constants MAX_SLOTS / FEE_PER_TX / NPC_RANGE
//   - Session lifecycle: open → has_session=true → close → has_session=false
//   - warehouse.list empty-when-no-db + row decoding (programmable DB)
//   - warehouse.deposit rejection matrix: bad_count, no_session (missing +
//     out-of-range), no_kinah, sp_failed
//   - warehouse.deposit happy path (kinah -10, SP invoked via programmableDB)
//   - warehouse.deposit sp_failed rollback restores kinah
//   - warehouse.withdraw parallel happy path + sp_failed rollback
//   - CM_WAREHOUSE_LIST (0xC5) handler wiring — dispatch_packet emits
//     SM_WAREHOUSE_LIST (0xC8) with zero-count body
//   - CM_WAREHOUSE_DEPOSIT (0xC6) handler wiring — dispatches without panic
//     and rejects when no session (kinah untouched)
//   - npc_798004 Warehouse Keeper dialog registration
package luahost

import (
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// newS15Bridge builds a fresh ECS World + Bridge + Lua state with all scripts
// loaded and mirrors the s14 harness. Warehouse tests reuse the s14 scripts
// directory since scripts/ is a single tree shared by every phase.
func newS15Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s14ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s15 loadScripts: %v", err)
	}
	return b, L, world, sender
}

// spawnS15Player creates a player entity with the stats warehouse.* reads
// (char_id, kinah, dead) plus a PositionComp at the given (x,y,z). Tests use
// the position to drive the range check via entity.get_nearby.
func spawnS15Player(t *testing.T, world *ecs.World,
	gw uint64, charID float64, name string, kinah float64, x, y, z float32) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "kinah", kinah)
	world.SetStat(eid, "dead", 0)
	world.SetPosition(eid, &ecs.PositionComp{X: x, Y: y, Z: z})
	return eid
}

// spawnS15WarehouseNpc creates a Warehouse Keeper NPC (template 798004) with a
// PositionComp. Opening a warehouse.open_session with this entity's id gives
// the test control over the range check.
func spawnS15WarehouseNpc(t *testing.T, world *ecs.World, x, y, z float32) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetNpc(eid, &ecs.NpcComp{TemplateID: 798004})
	world.SetPosition(eid, &ecs.PositionComp{X: x, Y: y, Z: z})
	return eid
}

// installWarehouseDB mirrors installMailDB: programs a Lua-side `_G.db.call`
// stub that answers a set of SP names with the given Lua row-table literals.
// Suffix "!err" makes db.call return `nil, "<err>"`.
func installWarehouseDB(t *testing.T, L *lua.LState, responses map[string]string) {
	t.Helper()
	src := `_G.db = { call = function(name, ...)
`
	for sp, rows := range responses {
		if len(sp) > 4 && sp[len(sp)-4:] == "!err" {
			realName := sp[:len(sp)-4]
			src += `    if name == "` + realName + `" then return nil, "` + rows + `" end
`
			continue
		}
		src += `    if name == "` + sp + `" then return ` + rows + ` end
`
	}
	src += `    return {}
end }
`
	if err := L.DoString(src); err != nil {
		t.Fatalf("installWarehouseDB DoString failed: %v\n%s", err, src)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseLibLoaded — warehouse global exists with all 6 functions.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseLibLoaded(t *testing.T) {
	_, L, _, _ := newS15Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("warehouse").(*lua.LTable)
	if !ok {
		t.Fatalf("expected warehouse to be a table, got %T", L.GetGlobal("warehouse"))
	}
	for _, fn := range []string{
		"list", "deposit", "withdraw",
		"open_session", "close_session", "has_session",
	} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected warehouse.%s to be a function, got %T",
				fn, L.GetField(tbl, fn))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseConstants — MAX_SLOTS=104, FEE_PER_TX=10, NPC_RANGE=15.0.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseConstants(t *testing.T) {
	_, L, _, _ := newS15Bridge(t)
	defer L.Close()

	tbl := L.GetGlobal("warehouse").(*lua.LTable)
	checks := map[string]lua.LNumber{
		"MAX_SLOTS":  104,
		"FEE_PER_TX": 10,
		"NPC_RANGE":  15.0,
	}
	for field, want := range checks {
		if v := L.GetField(tbl, field); v != want {
			t.Errorf("warehouse.%s: want %v, got %v", field, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseSessionLifecycle — open_session stores the binding,
// has_session reports true, close_session clears it.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseSessionLifecycle(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1500, 15001, "Opener", 100, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 1, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	chunk := `
_before = warehouse.has_session(EID)
warehouse.open_session(EID, NPC)
_during = warehouse.has_session(EID)
warehouse.close_session(EID)
_after  = warehouse.has_session(EID)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_before"); v != lua.LFalse {
		t.Errorf("has_session before open: want false, got %v", v)
	}
	if v := L.GetGlobal("_during"); v != lua.LTrue {
		t.Errorf("has_session after open: want true, got %v", v)
	}
	if v := L.GetGlobal("_after"); v != lua.LFalse {
		t.Errorf("has_session after close: want false, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseListEmptyWithoutDb — with _G.db=nil, warehouse.list returns
// an empty array (graceful degradation, no error).
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseListEmptyWithoutDb(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1501, 15002, "Reader", 0, 0, 0, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_G.db = nil`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if err := L.DoString(`_rows = warehouse.list(EID); _n = #_rows`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(0) {
		t.Errorf("expected empty list when db=nil, got count=%v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseListReturnsRows — SP aion_GetWarehouseByUser returns 3 rows
// and warehouse.list surfaces all 3 with fields intact.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseListReturnsRows(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1502, 15003, "Reader", 0, 0, 0, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installWarehouseDB(t, L, map[string]string{
		"aion_GetWarehouseByUser": `{
			[1]={item_id=100001, item_count=1, slot=0},
			[2]={item_id=100002, item_count=5, slot=1},
			[3]={item_id=100003, item_count=9, slot=2}
		}`,
	})

	chunk := `
_rows = warehouse.list(EID)
_n   = #_rows
_id1 = _rows[1].item_id
_id2 = _rows[2].item_id
_id3 = _rows[3].item_id
_sl3 = _rows[3].slot
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(3) {
		t.Fatalf("want 3 rows, got %v", v)
	}
	if v := L.GetGlobal("_id1"); v != lua.LNumber(100001) {
		t.Errorf("row1 item_id wrong: %v", v)
	}
	if v := L.GetGlobal("_id2"); v != lua.LNumber(100002) {
		t.Errorf("row2 item_id wrong: %v", v)
	}
	if v := L.GetGlobal("_id3"); v != lua.LNumber(100003) {
		t.Errorf("row3 item_id wrong: %v", v)
	}
	if v := L.GetGlobal("_sl3"); v != lua.LNumber(2) {
		t.Errorf("row3 slot wrong: %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseDepositBadCount — item_id<=0 or count<=0 yields bad_count and
// touches neither kinah nor the DB.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseDepositBadCount(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1503, 15004, "BadDep", 1000, 0, 0, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// count=0 branch
	if err := L.DoString(`_ok, _r = warehouse.deposit(EID, 100001, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on count=0, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_count") {
		t.Errorf("want reason=bad_count, got %v", v)
	}

	// item_id=0 branch
	if err := L.DoString(`_ok2, _r2 = warehouse.deposit(EID, 0, 1)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok2"); v != lua.LFalse {
		t.Errorf("want ok=false on item_id=0, got %v", v)
	}
	if v := L.GetGlobal("_r2"); v != lua.LString("bad_count") {
		t.Errorf("want reason=bad_count on item_id=0, got %v", v)
	}

	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must be untouched on bad_count, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseDepositNoSession — deposit without prior open_session must
// reject as no_session with zero kinah spent.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseDepositNoSession(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1504, 15005, "NoSess", 500, 0, 0, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = warehouse.deposit(EID, 100001, 1)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false with no session, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("no_session") {
		t.Errorf("want reason=no_session, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be untouched on no_session, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseDepositOutOfRange — open_session with an NPC placed >NPC_RANGE
// metres away. warehouse.deposit must reject as no_session even though the
// session table holds a binding, because _in_range returns false.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseDepositOutOfRange(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	// Player at origin, NPC 100 metres away on X axis.
	eid := spawnS15Player(t, world, 1505, 15006, "Walker", 500, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 100, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	chunk := `
warehouse.open_session(EID, NPC)
_ok, _r = warehouse.deposit(EID, 100001, 1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false when NPC out of range, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("no_session") {
		t.Errorf("want reason=no_session on out-of-range, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be untouched on out-of-range, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseDepositNoKinah — session open + NPC in range, but player has
// only 5 kinah (< FEE_PER_TX=10). deposit must fail with no_kinah.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseDepositNoKinah(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1506, 15007, "Broke", 5, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 1, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	chunk := `
warehouse.open_session(EID, NPC)
_ok, _r = warehouse.deposit(EID, 100001, 1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on insufficient kinah, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("no_kinah") {
		t.Errorf("want reason=no_kinah, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 5 {
		t.Errorf("kinah must stay at 5 on no_kinah, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseDepositHappyPath — session open, NPC in range, 500 kinah.
// deposit returns true, kinah drops to 490, and aion_DepositItemUser was
// invoked on the Go-side DBBridge (observed via programmableDB).
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseDepositHappyPath(t *testing.T) {
	b, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1507, 15008, "Happy", 500, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 2, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	// Observe SP invocation via programmableDB. aion_DepositItemUser returns
	// empty rows (success). The Lua `_G.db.call` call funnels through the
	// same DBBridge because registerDB forwards to b.DB.
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			// deliberately empty — warehouse.deposit doesn't inspect rows
		},
	}
	b.DB = pdb

	chunk := `
warehouse.open_session(EID, NPC)
_ok, _r = warehouse.deposit(EID, 100001, 3)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Fatalf("want ok=true on happy path, got %v (reason=%v)",
			v, L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 490 {
		t.Errorf("kinah should drop to 490, got %v", k)
	}
	if !pdb.sawCall("aion_DepositItemUser") {
		t.Errorf("expected aion_DepositItemUser SP call, calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseDepositRollsBackOnSpFail — session open, 500 kinah, but the
// aion_DepositItemUser SP returns an error. warehouse.deposit must refund the
// FEE_PER_TX via player.add_kinah so kinah is restored to 500.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseDepositRollsBackOnSpFail(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1508, 15009, "Rollback", 500, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 3, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	installWarehouseDB(t, L, map[string]string{
		"aion_DepositItemUser!err": "db_outage",
	})

	chunk := `
warehouse.open_session(EID, NPC)
_ok, _r = warehouse.deposit(EID, 100001, 1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on SP failure, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("sp_failed") {
		t.Errorf("want reason=sp_failed, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be refunded to 500 on sp_failed, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseWithdrawBadCount — count<=0 → bad_count, no side effects.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseWithdrawBadCount(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1509, 15010, "BadWd", 1000, 0, 0, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = warehouse.withdraw(EID, 100001, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on count=0, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_count") {
		t.Errorf("want reason=bad_count, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must be untouched on bad_count, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseWithdrawHappyPath — session + range + 500 kinah → true,
// kinah→490, aion_WithdrawItemUser SP observed.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseWithdrawHappyPath(t *testing.T) {
	b, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1510, 15011, "WdHappy", 500, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 2, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	pdb := &programmableDB{rows: map[string][]map[string]any{}}
	b.DB = pdb

	chunk := `
warehouse.open_session(EID, NPC)
_ok, _r = warehouse.withdraw(EID, 100001, 2)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Fatalf("want ok=true on withdraw happy, got %v (reason=%v)",
			v, L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 490 {
		t.Errorf("kinah should drop to 490, got %v", k)
	}
	if !pdb.sawCall("aion_WithdrawItemUser") {
		t.Errorf("expected aion_WithdrawItemUser SP call, calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestWarehouseWithdrawRollsBackOnSpFail — SP error → false,"sp_failed" and
// the kinah fee is refunded.
// ─────────────────────────────────────────────────────────────────────────────
func TestWarehouseWithdrawRollsBackOnSpFail(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1511, 15012, "WdRollback", 500, 0, 0, 0)
	npcEid := spawnS15WarehouseNpc(t, world, 3, 0, 0)

	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("NPC", lua.LNumber(float64(npcEid)))

	installWarehouseDB(t, L, map[string]string{
		"aion_WithdrawItemUser!err": "timeout",
	})

	chunk := `
warehouse.open_session(EID, NPC)
_ok, _r = warehouse.withdraw(EID, 100001, 1)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on SP failure, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("sp_failed") {
		t.Errorf("want reason=sp_failed, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be refunded to 500 on sp_failed, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmWarehouseListHandlerRegistered — dispatch_packet(0xC5, "") runs the
// cm_warehouse_list handler and captures exactly one SM_WAREHOUSE_LIST (0xC8)
// packet back to the caller's gateway. Payload starts with int32 count=0.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmWarehouseListHandlerRegistered(t *testing.T) {
	_, L, world, sender := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1512, 15013, "Dispatch", 0, 0, 0, 0)

	// No rows from the SP → count=0 in the SM_WAREHOUSE_LIST response.
	installWarehouseDB(t, L, map[string]string{
		"aion_GetWarehouseByUser": `{}`,
	})

	sender.packets = nil

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1512))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xC5), ctx, lua.LString(""))
	if err != nil {
		t.Fatalf("dispatch_packet(0xC5) returned error: %v", err)
	}

	// Exactly one SM_WAREHOUSE_LIST (0xC8) to gw 1512 with 4-byte count=0 body.
	var got int
	for _, p := range sender.sentToGateway(1512) {
		if p.opcode != 0xC8 {
			continue
		}
		got++
		if len(p.payload) < 4 {
			t.Errorf("SM_WAREHOUSE_LIST payload too short: %d bytes", len(p.payload))
			continue
		}
		count := int32(p.payload[0]) | int32(p.payload[1])<<8 |
			int32(p.payload[2])<<16 | int32(p.payload[3])<<24
		if count != 0 {
			t.Errorf("SM_WAREHOUSE_LIST count: want 0, got %d", count)
		}
	}
	if got != 1 {
		t.Errorf("expected 1 SM_WAREHOUSE_LIST (0xC8) on gw 1512, got %d", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmWarehouseDepositHandlerRegistered — dispatch_packet(0xC6, payload) with
// an int32 item_id + int32 count runs the cm_warehouse_deposit handler without
// error. With no warehouse session the deposit is rejected at the lib layer;
// the test only verifies wiring and payload parsing. Kinah must not have been
// spent because the reject fires before the fee deduction.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmWarehouseDepositHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS15Bridge(t)
	defer L.Close()

	eid := spawnS15Player(t, world, 1513, 15014, "DepDisp", 1000, 0, 0, 0)

	// int32 item_id=100001, int32 count=1 (little-endian).
	payload := []byte{
		0xA1, 0x86, 0x01, 0x00, // 100001
		0x01, 0x00, 0x00, 0x00, // 1
	}

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1513))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xC6), ctx, lua.LString(string(payload)))
	if err != nil {
		t.Fatalf("dispatch_packet(0xC6) returned error: %v", err)
	}

	// Without a session the handler rejects at warehouse.deposit before the
	// kinah spend, so the cached balance must be unchanged.
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must stay at 1000 when deposit rejected, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestNpc798004Registered — dialog.has(798004) returns true, confirming the
// Warehouse Keeper NPC script has been loaded and registered its dialog.
// ─────────────────────────────────────────────────────────────────────────────
func TestNpc798004Registered(t *testing.T) {
	_, L, _, _ := newS15Bridge(t)
	defer L.Close()

	if err := L.DoString(`_has = dialog.has(798004)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_has"); v != lua.LTrue {
		t.Errorf("expected dialog.has(798004)==true after loadScripts, got %v", v)
	}
}
