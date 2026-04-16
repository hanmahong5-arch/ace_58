// Package luahost — Phase S-10 regression tests.
//
// Covers:
//   - legion global table with rank constants and all public functions
//   - legion.create with nil DB → "db_failed" + kinah refunded
//   - legion.create with mock DB returning valid id → cache populated
//   - legion.create duplicate name (SP returns -1) → false + refund
//   - legion.create with zero kinah → "no_kinah", no cache, no DB call
//   - legion.invite with insufficient rank → "no_rights"
//   - legion.invite → accept two-player flow: member count=2, rank=DEPUTY
//   - legion.invite when target already in legion → "target_in_legion"
//   - legion.leave (non-master) → removes from roster and _member_legion
//   - legion.leave (master) → "master_cannot_leave"
//   - legion.kick by master → target removed
//   - legion.kick by non-master → "no_rights"
//   - legion.kick self (master kicks own name) → "cannot_kick_master"
//   - legion.disband by master → all members cleared, _legions[id]=nil
//   - legion.set_motd by officer → motd updated
//   - legion.set_motd with 300-char string → "too_long"
//   - CM_LEGION_* (0xB0-0xB5) handlers all registered (no "unknown opcode")
//   - CH_LEGION chat routes packet only to legion members, not bystanders
package luahost

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// s10ScriptsDir points to the Lua scripts directory from this test's working dir.
var s10ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// capturedPacket records a single packet delivery by mockCaptureSender.
type capturedPacket struct {
	gatewaySeqID uint64
	opcode       uint16
	payload      []byte
}

// mockCaptureSender records every packet so tests can assert routing.
type mockCaptureSender struct {
	packets []capturedPacket
}

func (m *mockCaptureSender) SendToPlayer(gw uint64, op uint16, payload []byte) error {
	m.packets = append(m.packets, capturedPacket{
		gatewaySeqID: gw,
		opcode:       op,
		payload:      append([]byte(nil), payload...),
	})
	return nil
}

// sentToGateway returns all packets sent to the given gateway seq ID.
func (m *mockCaptureSender) sentToGateway(gw uint64) []capturedPacket {
	var out []capturedPacket
	for _, p := range m.packets {
		if p.gatewaySeqID == gw {
			out = append(out, p)
		}
	}
	return out
}

// newS10Bridge creates an ECS World and a Bridge with a capture sender, then loads
// all Lua scripts. Mirrors the setup pattern used by s7_test.go / s9_test.go.
func newS10Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s10ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s10 loadScripts: %v", err)
	}
	// Reset legion state so tests are isolated.
	if err := L.DoString(`legion._reset()`); err != nil {
		L.Close()
		t.Fatalf("legion._reset failed: %v", err)
	}
	return b, L, world, sender
}

// spawnPlayerWithCharID creates an ECS entity with a GatewaySeqID, char_id stat,
// and CharName, and sets an initial kinah balance.
func spawnPlayerWithCharID(t *testing.T, world *ecs.World, L *lua.LState,
	gw uint64, charID float64, name string, kinah float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "race", 0)
	world.SetStat(eid, "kinah", kinah)
	return eid
}

// injectMockDB overrides the global db.call in Lua to return a hardcoded result
// for a given SP name and returns the row for all other SPs as empty.
// `spName` and `rowLua` are Lua expressions for the SP name and return row.
func injectMockDB(t *testing.T, L *lua.LState, spName, rowLua string) {
	t.Helper()
	chunk := fmt.Sprintf(`
_G.db = {
    call = function(name, ...)
        if name == %q then
            return {[1]=%s}
        end
        return {}
    end
}
`, spName, rowLua)
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("injectMockDB DoString failed: %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionLibLoaded — legion global is a table exposing all public symbols.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionLibLoaded(t *testing.T) {
	_, L, _, _ := newS10Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("legion").(*lua.LTable)
	if !ok {
		t.Fatalf("expected legion to be a table, got %T", L.GetGlobal("legion"))
	}

	// All public functions must be callable.
	for _, fn := range []string{
		"create", "invite", "accept", "leave", "kick", "disband",
		"set_motd", "get", "member_gateways", "load_from_db", "_reset",
	} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected legion.%s to be a function, got %T", fn, L.GetField(tbl, fn))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionRankConstants — all four rank constants have the correct values.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionRankConstants(t *testing.T) {
	_, L, _, _ := newS10Bridge(t)
	defer L.Close()

	tbl := L.GetGlobal("legion").(*lua.LTable)
	checks := map[string]lua.LNumber{
		"RANK_BRIGADE_GENERAL": 0,
		"RANK_CENTURION":       1,
		"RANK_LEGIONARY":       2,
		"RANK_DEPUTY":          3,
	}
	for field, want := range checks {
		if v := L.GetField(tbl, field); v != want {
			t.Errorf("legion.%s: want %v, got %v", field, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionCreateNoDB — with the default nil-return mockDB (empty rows),
// create must return false,"db_failed" and refund the kinah.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionCreateNoDB(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	eid := spawnPlayerWithCharID(t, world, L, 601, 1001, "Alice", 200000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Default Bridge.DB is mockDB which returns nil rows → legion.create sees empty rows → db_failed.
	if err := L.DoString(`_s10_ok, _s10_reason = legion.create(EID, "IronGuard")`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for nil DB rows, got %v", v)
	}
	if v := L.GetGlobal("_s10_reason"); v != lua.LString("db_failed") {
		t.Errorf("want reason=db_failed, got %v", v)
	}

	// Kinah must be refunded: 200000 - 100000 + 100000 = 200000.
	kinah, _ := world.GetStat(eid, "kinah")
	if kinah != 200000 {
		t.Errorf("kinah should be refunded to 200000, got %v", kinah)
	}

	// Cache must be empty.
	if err := L.DoString(`_s10_leg = legion.get(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s10_leg"); v != lua.LNil {
		t.Errorf("expected legion.get to return nil after db_failed, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionCreateWithMockDB — inject db.call returning new_id=42; verify cache.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionCreateWithMockDB(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	eid := spawnPlayerWithCharID(t, world, L, 602, 1002, "Bob", 500000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))
	L.SetGlobal("CID", lua.LNumber(1002))

	// Override db.call: aion_PutGuild_20100916 returns {new_id=42}; all others empty.
	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=42}`)

	if err := L.DoString(`_s10_ok, _s10_id = legion.create(EID, "SteelLegion")`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_ok"); v != lua.LTrue {
		t.Errorf("want ok=true, got %v (id=%v)", v, L.GetGlobal("_s10_id"))
	}
	if v := L.GetGlobal("_s10_id"); v != lua.LNumber(42) {
		t.Errorf("want returned id=42, got %v", v)
	}

	// Verify cache contents via legion.get.
	chunk := `
local leg = legion.get(EID)
if leg then
    _s10_leg_id     = leg.id
    _s10_leg_name   = leg.name
    _s10_leg_master = leg.master
    _s10_mem_count  = 0
    for _ in pairs(leg.members) do _s10_mem_count = _s10_mem_count + 1 end
    _s10_mem_rank   = leg.members[CID] and leg.members[CID].rank or -1
else
    _s10_leg_id = -1
end
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString cache-check failed: %v", err)
	}

	if v := L.GetGlobal("_s10_leg_id"); v != lua.LNumber(42) {
		t.Errorf("want leg.id=42, got %v", v)
	}
	if v := L.GetGlobal("_s10_leg_name"); v != lua.LString("SteelLegion") {
		t.Errorf("want leg.name=SteelLegion, got %v", v)
	}
	if v := L.GetGlobal("_s10_leg_master"); v != lua.LNumber(1002) {
		t.Errorf("want leg.master=1002 (CID), got %v", v)
	}
	if v := L.GetGlobal("_s10_mem_count"); v != lua.LNumber(1) {
		t.Errorf("want member count=1, got %v", v)
	}
	if v := L.GetGlobal("_s10_mem_rank"); v != lua.LNumber(0) { // BRIGADE_GENERAL=0
		t.Errorf("want founder rank=0 (BRIGADE_GENERAL), got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionCreateDuplicateName — SP returns {new_id=-1} → dup_name, no cache, refund.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionCreateDuplicateName(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	eid := spawnPlayerWithCharID(t, world, L, 603, 1003, "Carol", 300000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=-1}`)

	if err := L.DoString(`_s10_dup_ok, _s10_dup_reason = legion.create(EID, "TakenName")`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_dup_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for dup name, got %v", v)
	}
	if v := L.GetGlobal("_s10_dup_reason"); v != lua.LString("dup_name") {
		t.Errorf("want reason=dup_name, got %v", v)
	}

	// Kinah must be fully refunded.
	kinah, _ := world.GetStat(eid, "kinah")
	if kinah != 300000 {
		t.Errorf("kinah should be refunded to 300000, got %v", kinah)
	}

	// Cache must be empty.
	if err := L.DoString(`_s10_dup_leg = legion.get(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s10_dup_leg"); v != lua.LNil {
		t.Errorf("expected nil cache after dup_name, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionCreateInsufficientKinah — player has 0 kinah → "no_kinah".
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionCreateInsufficientKinah(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	eid := spawnPlayerWithCharID(t, world, L, 604, 1004, "Dave", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Should not reach DB at all.
	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=99}`)

	if err := L.DoString(`_s10_nk_ok, _s10_nk_reason = legion.create(EID, "PoorLegion")`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_nk_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for no kinah, got %v", v)
	}
	if v := L.GetGlobal("_s10_nk_reason"); v != lua.LString("no_kinah") {
		t.Errorf("want reason=no_kinah, got %v", v)
	}

	// Kinah remains 0.
	kinah, _ := world.GetStat(eid, "kinah")
	if kinah != 0 {
		t.Errorf("kinah should stay 0, got %v", kinah)
	}

	// Cache must be empty.
	if err := L.DoString(`_s10_nk_leg = legion.get(EID)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_s10_nk_leg"); v != lua.LNil {
		t.Errorf("expected nil cache after no_kinah, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionInviteNoRights — LEGIONARY-ranked founder cannot invite.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionInviteNoRights(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 611, 1011, "Elf", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 612, 1012, "Orc", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))
	L.SetGlobal("CID1", lua.LNumber(1011))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=50}`)

	// Create the legion first.
	if err := L.DoString(`legion.create(EID1, "FrostGuard")`); err != nil {
		t.Fatalf("create DoString failed: %v", err)
	}

	// Demote founder to LEGIONARY via direct Lua access.
	if err := L.DoString(`
local leg = legion.get(EID1)
leg.members[CID1].rank = legion.RANK_LEGIONARY
`); err != nil {
		t.Fatalf("demote DoString failed: %v", err)
	}

	if err := L.DoString(`_s10_nr_ok, _s10_nr_reason = legion.invite(EID1, EID2)`); err != nil {
		t.Fatalf("invite DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_nr_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for LEGIONARY invite, got %v", v)
	}
	if v := L.GetGlobal("_s10_nr_reason"); v != lua.LString("no_rights") {
		t.Errorf("want reason=no_rights, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionInviteAcceptFlow — full invite→accept: second player joins as DEPUTY.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionInviteAcceptFlow(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 621, 1021, "Leon", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 622, 1022, "Lyra", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))
	L.SetGlobal("CID2", lua.LNumber(1022))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=55}`)

	chunk := `
_s10_create_ok = legion.create(EID1, "LegionAlpha")
_s10_inv_ok, _s10_inv_reason = legion.invite(EID1, EID2)
_s10_acc_ok, _s10_acc_reason = legion.accept(EID2)
local leg = legion.get(EID1)
if leg then
    _s10_acc_count = 0
    for _ in pairs(leg.members) do _s10_acc_count = _s10_acc_count + 1 end
    _s10_acc_rank2 = leg.members[CID2] and leg.members[CID2].rank or -1
else
    _s10_acc_count = -1
    _s10_acc_rank2 = -1
end
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("invite/accept DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_create_ok"); v != lua.LTrue {
		t.Errorf("create should succeed, got %v", v)
	}
	if v := L.GetGlobal("_s10_inv_ok"); v != lua.LTrue {
		t.Errorf("invite should succeed, got %v (reason=%v)",
			v, L.GetGlobal("_s10_inv_reason"))
	}
	if v := L.GetGlobal("_s10_acc_ok"); v != lua.LTrue {
		t.Errorf("accept should succeed, got %v (reason=%v)",
			v, L.GetGlobal("_s10_acc_reason"))
	}
	if v := L.GetGlobal("_s10_acc_count"); v != lua.LNumber(2) {
		t.Errorf("want member count=2 after accept, got %v", v)
	}
	if v := L.GetGlobal("_s10_acc_rank2"); v != lua.LNumber(3) { // RANK_DEPUTY=3
		t.Errorf("want second member rank=3 (DEPUTY), got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionInviteAlreadyInLegion — target already in a legion → "target_in_legion".
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionInviteAlreadyInLegion(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 631, 1031, "Max", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 632, 1032, "Mia", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))
	L.SetGlobal("CID2", lua.LNumber(1032))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=60}`)

	// Seed e2 as if already in a different legion by setting _member_legion[cid2].
	chunk := `
legion.create(EID1, "BronzeLegion")
-- Manually mark target as already having a legion membership.
-- We cannot access the module-local _member_legion directly, but
-- we can inject via accept after a manual invite setup.
_member_legion_hack = false
do
    -- Use invite+accept to properly enroll CID2; first create a second legion
    -- on EID2 — but EID2 has no kinah. Instead directly manipulate via the
    -- accepted invite path by tricking accept with a synthetic invite record.
    -- The cleanest approach: do a real invite/accept to enroll CID2, then
    -- try to invite CID2 again from a third entity and check the guard.
    local ok, reason = legion.invite(EID1, EID2)
    if ok then
        legion.accept(EID2)
    end
end
_s10_til_ok, _s10_til_reason = legion.invite(EID1, EID2)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_til_ok"); v != lua.LFalse {
		t.Errorf("want ok=false for already-in-legion target, got %v", v)
	}
	if v := L.GetGlobal("_s10_til_reason"); v != lua.LString("target_in_legion") {
		t.Errorf("want reason=target_in_legion, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionLeave — non-master member can leave; roster shrinks, mapping cleared.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionLeave(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 641, 1041, "Fox", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 642, 1042, "Ivy", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=70}`)

	chunk := `
legion.create(EID1, "SwiftLegion")
legion.invite(EID1, EID2)
legion.accept(EID2)

_s10_leave_ok, _s10_leave_reason = legion.leave(EID2)

local leg = legion.get(EID1)
_s10_leave_count = 0
for _ in pairs(leg.members) do _s10_leave_count = _s10_leave_count + 1 end

-- EID2 must no longer have a legion.
_s10_leave_leg2 = legion.get(EID2)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_leave_ok"); v != lua.LTrue {
		t.Errorf("want leave ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s10_leave_reason"))
	}
	if v := L.GetGlobal("_s10_leave_count"); v != lua.LNumber(1) {
		t.Errorf("want roster size=1 after leave, got %v", v)
	}
	if v := L.GetGlobal("_s10_leave_leg2"); v != lua.LNil {
		t.Errorf("expected nil legion for EID2 after leave, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionLeaveMasterBlocked — master calling leave returns "master_cannot_leave".
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionLeaveMasterBlocked(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 651, 1051, "Boss", 500000)
	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=75}`)

	if err := L.DoString(`
legion.create(EID1, "RulerLegion")
_s10_mlb_ok, _s10_mlb_reason = legion.leave(EID1)
`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_mlb_ok"); v != lua.LFalse {
		t.Errorf("want leave ok=false for master, got %v", v)
	}
	if v := L.GetGlobal("_s10_mlb_reason"); v != lua.LString("master_cannot_leave") {
		t.Errorf("want reason=master_cannot_leave, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionKickByMaster — master kicks a member by name; target removed.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionKickByMaster(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 661, 1061, "King", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 662, 1062, "Pawn", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))
	L.SetGlobal("CID2", lua.LNumber(1062))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=80}`)

	chunk := `
legion.create(EID1, "KingdomLegion")
legion.invite(EID1, EID2)
legion.accept(EID2)

_s10_kick_ok, _s10_kick_reason = legion.kick(EID1, "Pawn")

local leg = legion.get(EID1)
_s10_kick_count = 0
for _ in pairs(leg.members) do _s10_kick_count = _s10_kick_count + 1 end
_s10_kick_pawn_in = (leg.members[CID2] ~= nil)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_kick_ok"); v != lua.LTrue {
		t.Errorf("want kick ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s10_kick_reason"))
	}
	if v := L.GetGlobal("_s10_kick_count"); v != lua.LNumber(1) {
		t.Errorf("want roster=1 after kick, got %v", v)
	}
	if v := L.GetGlobal("_s10_kick_pawn_in"); v != lua.LFalse {
		t.Errorf("want kicked member absent from roster, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionKickNotMaster — non-master cannot kick → "no_rights".
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionKickNotMaster(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 671, 1071, "Chief", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 672, 1072, "Guard", 0)
	e3 := spawnPlayerWithCharID(t, world, L, 673, 1073, "Victim", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))
	L.SetGlobal("EID3", lua.LNumber(float64(e3)))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=85}`)

	chunk := `
legion.create(EID1, "ChiefLegion")
legion.invite(EID1, EID2)
legion.accept(EID2)
legion.invite(EID1, EID3)
legion.accept(EID3)

_s10_knm_ok, _s10_knm_reason = legion.kick(EID2, "Victim")
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_knm_ok"); v != lua.LFalse {
		t.Errorf("want kick ok=false for non-master, got %v", v)
	}
	if v := L.GetGlobal("_s10_knm_reason"); v != lua.LString("no_rights") {
		t.Errorf("want reason=no_rights, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionKickSelfMaster — master cannot kick themselves → "cannot_kick_master".
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionKickSelfMaster(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 681, 1081, "SelfKick", 500000)
	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=90}`)

	if err := L.DoString(`
legion.create(EID1, "SelfLegion")
_s10_ksm_ok, _s10_ksm_reason = legion.kick(EID1, "SelfKick")
`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_ksm_ok"); v != lua.LFalse {
		t.Errorf("want kick ok=false when kicking self, got %v", v)
	}
	if v := L.GetGlobal("_s10_ksm_reason"); v != lua.LString("cannot_kick_master") {
		t.Errorf("want reason=cannot_kick_master, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionDisband — master disbands; all members cleared, legion gone from cache.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionDisband(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 691, 1091, "Warlord", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 692, 1092, "Soldier", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=95}`)

	chunk := `
local ok, lid = legion.create(EID1, "WarLegion")
_s10_dis_lid = lid
legion.invite(EID1, EID2)
legion.accept(EID2)

_s10_dis_ok, _s10_dis_reason = legion.disband(EID1)

-- Both entities must now have no legion.
_s10_dis_leg1 = legion.get(EID1)
_s10_dis_leg2 = legion.get(EID2)
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_dis_ok"); v != lua.LTrue {
		t.Errorf("want disband ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s10_dis_reason"))
	}
	if v := L.GetGlobal("_s10_dis_leg1"); v != lua.LNil {
		t.Errorf("want nil legion for EID1 after disband, got %v", v)
	}
	if v := L.GetGlobal("_s10_dis_leg2"); v != lua.LNil {
		t.Errorf("want nil legion for EID2 after disband, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionSetMotd — CENTURION-rank officer can set MOTD; it persists in cache.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionSetMotd(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 701, 1101, "Cmdr", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 702, 1102, "Officer", 0)

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))
	L.SetGlobal("CID2", lua.LNumber(1102))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=100}`)

	chunk := `
legion.create(EID1, "MotdLegion")
legion.invite(EID1, EID2)
legion.accept(EID2)

-- Promote e2 to CENTURION so they can set MOTD.
do
    local leg = legion.get(EID1)
    leg.members[CID2].rank = legion.RANK_CENTURION
end

_s10_motd_ok, _s10_motd_reason = legion.set_motd(EID2, "Welcome to the legion!")
local leg = legion.get(EID1)
_s10_motd_val = leg and leg.motd or ""
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_motd_ok"); v != lua.LTrue {
		t.Errorf("want set_motd ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_s10_motd_reason"))
	}
	if v := L.GetGlobal("_s10_motd_val"); v != lua.LString("Welcome to the legion!") {
		t.Errorf("want motd='Welcome to the legion!', got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionSetMotdTooLong — 300-char MOTD is rejected with "too_long".
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionSetMotdTooLong(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e1 := spawnPlayerWithCharID(t, world, L, 711, 1111, "Verbose", 500000)
	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=101}`)

	// Build a 300-character string.
	longMotd := strings.Repeat("X", 300)

	chunk := fmt.Sprintf(`
legion.create(EID1, "LongMotdLegion")
_s10_tl_ok, _s10_tl_reason = legion.set_motd(EID1, %q)
`, longMotd)

	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}

	if v := L.GetGlobal("_s10_tl_ok"); v != lua.LFalse {
		t.Errorf("want set_motd ok=false for long MOTD, got %v", v)
	}
	if v := L.GetGlobal("_s10_tl_reason"); v != lua.LString("too_long") {
		t.Errorf("want reason=too_long, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmLegionHandlersRegistered — opcodes 0xB0-0xB5 are all registered.
// dispatch_packet must not return "unknown opcode" Lua error for any of them.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmLegionHandlersRegistered(t *testing.T) {
	_, L, world, _ := newS10Bridge(t)
	defer L.Close()

	e := world.NewEntity()
	world.SetPlayer(e, &ecs.PlayerComp{GatewaySeqID: 800})
	world.SetStat(e, "char_id", 9001)
	world.SetStat(e, "dead", 0)

	L.SetGlobal("current_tick", lua.LNumber(1))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(800))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	for _, op := range []lua.LNumber{0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5} {
		err := L.CallByParam(lua.P{
			Fn:      dispatchFn,
			NRet:    0,
			Protect: true,
		}, op, ctx, lua.LString(""))
		if err != nil {
			t.Errorf("dispatch_packet(0x%02X) returned unexpected error: %v",
				int(op), err)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestLegionChatRoutesToMembers — CH_LEGION (0x04) chat is delivered only to
// legion members, not to bystanders outside the legion.
// ─────────────────────────────────────────────────────────────────────────────
func TestLegionChatRoutesToMembers(t *testing.T) {
	_, L, world, sender := newS10Bridge(t)
	defer L.Close()

	// Create two legion members and one bystander.
	e1 := spawnPlayerWithCharID(t, world, L, 901, 2001, "Alpha", 500000)
	e2 := spawnPlayerWithCharID(t, world, L, 902, 2002, "Beta", 0)
	e3 := spawnPlayerWithCharID(t, world, L, 903, 2003, "Bystander", 0) // not in legion
	// Ensure e3 is in the world so AllPlayers can return it.
	_ = e3

	L.SetGlobal("EID1", lua.LNumber(float64(e1)))
	L.SetGlobal("EID2", lua.LNumber(float64(e2)))

	injectMockDB(t, L, "aion_PutGuild_20100916", `{new_id=200}`)

	// Form the legion.
	if err := L.DoString(`
legion.create(EID1, "ChatLegion")
legion.invite(EID1, EID2)
legion.accept(EID2)
`); err != nil {
		t.Fatalf("legion setup DoString failed: %v", err)
	}

	// Clear captured packets so only the chat dispatch counts.
	sender.packets = nil

	// Build a CH_LEGION chat payload:
	//   byte channel=0x04, utf16_null target (empty), utf16_null message "Hi"
	var payload []byte
	payload = append(payload, 0x04) // CH_LEGION
	// empty target_name UTF-16 null
	payload = append(payload, 0x00, 0x00)
	// message "Hi" as UTF-16 LE + null
	payload = append(payload, 'H', 0x00, 'i', 0x00, 0x00, 0x00)

	L.SetGlobal("current_tick", lua.LNumber(100))

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(e1)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(901))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("alpha"))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0x46), ctx, lua.LString(string(payload)))
	if err != nil {
		t.Fatalf("dispatch_packet(0x46 CH_LEGION) failed: %v", err)
	}

	// Verify: packets must have been sent to GW 901 and 902 (legion members)
	// but NOT to GW 903 (bystander).
	to901 := sender.sentToGateway(901)
	to902 := sender.sentToGateway(902)
	to903 := sender.sentToGateway(903)

	if len(to901) == 0 {
		t.Error("expected at least one packet to member GW 901, got none")
	}
	if len(to902) == 0 {
		t.Error("expected at least one packet to member GW 902, got none")
	}
	if len(to903) != 0 {
		t.Errorf("expected no packets to bystander GW 903, got %d", len(to903))
	}
}
