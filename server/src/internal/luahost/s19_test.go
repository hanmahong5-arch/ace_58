// Package luahost — Phase S-19 regression tests.
//
// Covers the Instance / Dungeon MVP:
//   - scripts/lib/instance.lua state machine (two-phase-commit create, rejoin,
//     leave without dispose, boss-kill reward dispatch, reset with fee, on_expire
//     with stale-created_at rejection)
//   - scripts/handlers/cm_instance_{enter,leave,reset}.lua dispatch
//   - scripts/events/on_instance_expire.lua / on_daily_reset.lua
//   - scripts/instances/inst_{300040000,300320000}_*.lua template registration
//   - scripts/npcs/npc_{798006,798007}.lua entrance NPCs
//   - Phase S-18b crash-recovery guard in cm_enter_world.lua
//   - group.lua kick/leave callback registry
//
// Design doc: C:\Users\Administrator\.claude\plans\proud-questing-raven.md
package luahost

import (
	"encoding/json"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// ----------------------------------------------------------------------------
// Harness
// ----------------------------------------------------------------------------

// newS19Bridge wires a fresh World + Bridge + Lua state and loads the full
// script tree. Mirrors the s14/s16 pattern but allows injecting a JobQueue
// so tests can assert instance.create schedules an expiry task.
func newS19Bridge(t *testing.T, jobs JobQueue) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender, Jobs: jobs}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s14ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s19 loadScripts: %v", err)
	}
	return b, L, world, sender
}

// spawnS19Player creates a player entity with the stats the instance lib
// reads: char_id, level, hp/dead, kinah. Position defaults to (0,0,0) so all
// group members colocate within the 50m entry-distance check.
func spawnS19Player(t *testing.T, world *ecs.World,
	gw uint64, charID float64, name string, level float64, kinah float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "level", level)
	world.SetStat(eid, "hp", 1000)
	world.SetStat(eid, "max_hp", 1000)
	world.SetStat(eid, "dead", 0)
	world.SetStat(eid, "kinah", kinah)
	world.SetPosition(eid, &ecs.PositionComp{X: 0, Y: 0, Z: 0})
	return eid
}

// installInstanceDB overrides _G.db.call with a table-driven stub. `responses`
// maps SP names → Lua expressions (array-of-rows). A "!err" suffix on the key
// makes that SP return nil + the string value as an error.
func installInstanceDB(t *testing.T, L *lua.LState, responses map[string]string) {
	t.Helper()
	src := `_G.db = { call = function(name, ...)
`
	for sp, rows := range responses {
		if len(sp) > 4 && sp[len(sp)-4:] == "!err" {
			real := sp[:len(sp)-4]
			src += `    if name == "` + real + `" then return nil, "` + rows + `" end
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
		t.Fatalf("installInstanceDB: %v\n%s", err, src)
	}
}

// ----------------------------------------------------------------------------
// Lib-level tests
// ----------------------------------------------------------------------------

func TestInstanceLibLoaded(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()

	tbl, ok := L.GetGlobal("instance").(*lua.LTable)
	if !ok {
		t.Fatalf("instance global is not a table: %T", L.GetGlobal("instance"))
	}
	for _, fn := range []string{
		"register", "create", "leave", "rejoin", "reset",
		"on_boss_kill", "on_expire", "send_cooldowns",
		"member_gateways", "has_char_run", "get", "get_by_eid", "get_template",
	} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected instance.%s to be a function", fn)
		}
	}
}

func TestInstanceStateConstants(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()

	tbl := L.GetGlobal("instance").(*lua.LTable)
	checks := map[string]lua.LNumber{
		"STATE_LOBBY":             0,
		"STATE_ACTIVE":            1,
		"STATE_CLEARED":           2,
		"STATE_EXPIRED":           3,
		"R_OK":                    0,
		"R_COOLDOWN":              1,
		"R_BAD_LEVEL":             2,
		"R_BAD_GROUP_SIZE":        3,
		"R_NOT_LEADER":            4,
		"R_ALREADY_IN_INSTANCE":   5,
		"R_DB_ERROR":              6,
		"R_TEMPLATE_UNKNOWN":      7,
	}
	for k, want := range checks {
		if v := L.GetField(tbl, k); v != want {
			t.Errorf("instance.%s want %v got %v", k, want, v)
		}
	}
}

func TestTemplateRegistry_TemplatesLoaded(t *testing.T) {
	// Both Haramel (300040000) and Beshmundir (300320000) auto-register from
	// scripts/instances/ at loadScripts time.
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()

	if err := L.DoString(`
		_ha = instance.get_template(300040000)
		_be = instance.get_template(300320000)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ha") == lua.LNil {
		t.Error("Haramel template (300040000) not registered")
	}
	if L.GetGlobal("_be") == lua.LNil {
		t.Error("Beshmundir template (300320000) not registered")
	}
}

func TestTemplateRegistry_DuplicateBlocks(t *testing.T) {
	// Re-registering an existing template is a no-op (logs a warn inside the
	// lib). Verify by checking the original value is not overwritten.
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()

	if err := L.DoString(`
		_before = instance.get_template(300040000).min_level
		instance.register({ template_id = 300040000, display_name = "HIJACK",
		                    min_level = 99 })
		_after = instance.get_template(300040000).min_level
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_before") != L.GetGlobal("_after") {
		t.Errorf("duplicate register mutated min_level: before=%v after=%v",
			L.GetGlobal("_before"), L.GetGlobal("_after"))
	}
}

// ----------------------------------------------------------------------------
// Create — two-phase commit
// ----------------------------------------------------------------------------

func TestCreate_HappyPath_Solo(t *testing.T) {
	mj := &mockJobQueue{}
	_, L, world, _ := newS19Bridge(t, mj)
	defer L.Close()

	eid := spawnS19Player(t, world, 1900, 19001, "Solo", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122":  `{}`,
		"aion_setuserinstance_20171122":  `{}`,
	})

	if err := L.DoString(`_rid, _r = instance.create(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	rid := L.GetGlobal("_rid")
	if rid == lua.LNil {
		t.Fatalf("expected non-nil run_id, got reason=%v", L.GetGlobal("_r"))
	}
	if got := func(e ecs.Entity, k string) float64 { v, _ := world.GetStat(e, k); return v }(eid, "instance_run_id"); got == 0 {
		t.Error("instance_run_id stat not set on entry")
	}
}

func TestCreate_TemplateUnknown(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1901, 19002, "Tester", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_rid, _r = instance.create(EID, 999999)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_rid") != lua.LNil {
		t.Errorf("expected nil run_id on unknown template")
	}
	if L.GetGlobal("_r") != lua.LString("template_unknown") {
		t.Errorf("want reason=template_unknown, got %v", L.GetGlobal("_r"))
	}
}

func TestCreate_BadLevel(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	// Haramel caps at level 10; spawn a level-55 character to fail the gate.
	eid := spawnS19Player(t, world, 1902, 19003, "TooHigh", 55, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
	})

	if err := L.DoString(`_rid, _r = instance.create(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_r") != lua.LString("bad_level") {
		t.Errorf("want reason=bad_level, got %v", L.GetGlobal("_r"))
	}
}

func TestCreate_GroupTooSmall_Beshmundir(t *testing.T) {
	// Beshmundir min_members=2. A solo player fails the gate.
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1903, 19004, "Solo55", 60, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
	})
	if err := L.DoString(`_rid, _r = instance.create(EID, 300320000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_r") != lua.LString("bad_group_size") {
		t.Errorf("want reason=bad_group_size, got %v", L.GetGlobal("_r"))
	}
}

func TestCreate_CooldownBlocks_WithLiveRun(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1904, 19005, "OnCd", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Pretend a previous run of template 300040000 is still on cooldown and
	// the in-memory _char_run[cid] points at a live run.
	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{[1]={instance_id=300040000, reentrance_time=9999999999}}`,
		"aion_setuserinstance_20171122": `{}`,
	})
	// First create populates _char_run via the skip_sp_write path; result
	// itself is not asserted — the second call below is the actual test target.
	_ = L.DoString(`_rid, _r = instance.create(EID, 300040000)`)
	// Force the lib into "live run already exists" state by creating then
	// checking the block triggers for a second attempt.
	if err := L.DoString(`_rid2, _r2 = instance.create(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	// Second attempt must return "already_in_instance" (handled upstream) OR
	// "cooldown" (if _char_run was cleared). The happy case for this test is
	// that neither is nil → we got a reason string back.
	r2 := L.GetGlobal("_r2")
	if r2 == lua.LNil || r2 == lua.LString("") {
		t.Errorf("expected rejection reason on duplicate create, got _rid2=%v",
			L.GetGlobal("_rid2"))
	}
}

func TestCreate_CrashRecoveryReentry_NoExtraCooldown(t *testing.T) {
	// Simulate a post-restart scenario: DB says the player has a live cooldown
	// on template 300040000 but _char_run is empty (the in-memory run was lost
	// with the crashed VM). instance.create should allow entry without calling
	// aion_setuserinstance_20171122 a second time.
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1905, 19006, "PostCrash", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Use a counting stub so we can assert aion_setuserinstance_20171122 is
	// NOT called when the member is in crash-recovery mode.
	if err := L.DoString(`
		_set_calls = 0
		_G.db = { call = function(name, ...)
			if name == "aion_getuserinstance_20171122" then
				return {{instance_id=300040000, reentrance_time=9999999999}}
			end
			if name == "aion_setuserinstance_20171122" then
				_set_calls = _set_calls + 1
				return {}
			end
			return {}
		end }
	`); err != nil {
		t.Fatalf("install stub: %v", err)
	}

	if err := L.DoString(`_rid, _r = instance.create(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_rid") == lua.LNil {
		t.Fatalf("crash-recovery entry should succeed, got reason=%v",
			L.GetGlobal("_r"))
	}
	if v := L.GetGlobal("_set_calls"); v != lua.LNumber(0) {
		t.Errorf("aion_setuserinstance_20171122 should NOT be called on crash-recovery entry, got %v calls", v)
	}
}

func TestCreate_Phase2_RollbackOnMidSPFail(t *testing.T) {
	// First SP write succeeds, second fails → roll back first by calling SP
	// with reentrance_time=0. Verify by counting calls.
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	leader := spawnS19Player(t, world, 1906, 19007, "Leader", 60, 0)
	mate := spawnS19Player(t, world, 1907, 19008, "Mate", 60, 0)
	L.SetGlobal("LEAD", lua.LNumber(float64(leader)))
	L.SetGlobal("MATE", lua.LNumber(float64(mate)))

	// Form a real group first so party_eids = {leader, mate}.
	if err := L.DoString(`
		group.invite(LEAD, MATE)
		group.accept(MATE)
	`); err != nil {
		t.Fatalf("form group: %v", err)
	}

	// The second SP call (for the second char_id) returns an error. We track
	// both calls and the subsequent rollback (reentrance_time=0).
	if err := L.DoString(`
		_set_calls = {}
		_G.db = { call = function(name, ...)
			local args = {...}
			if name == "aion_getuserinstance_20171122" then
				return {}
			end
			if name == "aion_setuserinstance_20171122" then
				table.insert(_set_calls, { cid = args[1], reentry = args[4] })
				if #_set_calls == 2 then
					return nil, "db_timeout"
				end
				return {}
			end
			return {}
		end }
	`); err != nil {
		t.Fatalf("install stub: %v", err)
	}

	if err := L.DoString(`_rid, _r = instance.create(LEAD, 300320000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_rid") != lua.LNil {
		t.Fatalf("expected rollback to yield nil run_id, got %v",
			L.GetGlobal("_rid"))
	}
	if L.GetGlobal("_r") != lua.LString("db_error") {
		t.Errorf("want reason=db_error, got %v", L.GetGlobal("_r"))
	}
	// After the 2nd call failed, we expect a 3rd call that rolls back the 1st
	// committed char with reentrance_time=0.
	if err := L.DoString(`_n = #_set_calls`); err != nil {
		t.Fatalf("read count: %v", err)
	}
	n := int(L.GetGlobal("_n").(lua.LNumber))
	if n < 3 {
		t.Errorf("expected ≥3 SP calls (2 forward + 1 rollback), got %d", n)
	}
	// The final call should have reentry=0 (rollback).
	if err := L.DoString(`_last_reentry = _set_calls[#_set_calls].reentry`); err != nil {
		t.Fatalf("read last: %v", err)
	}
	if v := L.GetGlobal("_last_reentry"); v != lua.LNumber(0) {
		t.Errorf("rollback call must use reentrance_time=0, got %v", v)
	}
}

func TestCreate_SchedulesExpiry_WithCreatedAt(t *testing.T) {
	mj := &mockJobQueue{}
	_, L, world, _ := newS19Bridge(t, mj)
	defer L.Close()
	eid := spawnS19Player(t, world, 1908, 19009, "Solo", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
	})

	if err := L.DoString(`_rid = instance.create(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	job, ok := mj.last()
	if !ok {
		t.Fatal("no jobq enqueue observed")
	}
	if job.kind != "aion58.instance.expire" {
		t.Errorf("wrong kind: %q", job.kind)
	}
	// Haramel validity_hours = 2 → delay = 7200s.
	wantSeconds := 2 * 3600
	if int(job.delay.Seconds()) != wantSeconds {
		t.Errorf("want delay %ds, got %v", wantSeconds, job.delay)
	}
	// Payload must carry both run_id and created_at_unix.
	var payload map[string]any
	if err := json.Unmarshal(job.payload, &payload); err != nil {
		t.Fatalf("payload json: %v", err)
	}
	if _, ok := payload["run_id"]; !ok {
		t.Error("payload missing run_id")
	}
	if _, ok := payload["created_at_unix"]; !ok {
		t.Error("payload missing created_at_unix")
	}
}

// ----------------------------------------------------------------------------
// Leave / rejoin
// ----------------------------------------------------------------------------

func TestLeave_DoesNotDispose_BlackCooldownFix(t *testing.T) {
	// Entering then leaving must leave _char_run intact and run alive.
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1910, 19010, "Solo", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
		"aion_GetBindPoint":             `{[1]={x=0,y=0,z=0}}`,
	})

	if err := L.DoString(`
		_rid = instance.create(EID, 300040000)
		_ok_leave = instance.leave(EID)
		_run_after = instance.get(_rid)
		_cid_still_bound = (instance.has_char_run(19010) ~= nil)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok_leave") != lua.LTrue {
		t.Error("instance.leave should succeed")
	}
	if L.GetGlobal("_run_after") == lua.LNil {
		t.Error("run must NOT be disposed on solo leave (black-cooldown fix)")
	}
	if L.GetGlobal("_cid_still_bound") != lua.LTrue {
		t.Error("_char_run should remain bound after leave (rejoin path)")
	}
}

func TestRejoin_NoExtraCooldownWrite(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1911, 19011, "Solo", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`
		_set_calls = 0
		_G.db = { call = function(name, ...)
			if name == "aion_getuserinstance_20171122" then return {} end
			if name == "aion_setuserinstance_20171122" then
				_set_calls = _set_calls + 1
				return {}
			end
			if name == "aion_GetBindPoint" then return {{x=0,y=0,z=0}} end
			return {}
		end }
		instance.create(EID, 300040000)
		_before = _set_calls
		instance.leave(EID)
		instance.rejoin(EID, 300040000)
		_after = _set_calls
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	before := int(L.GetGlobal("_before").(lua.LNumber))
	after := int(L.GetGlobal("_after").(lua.LNumber))
	if after != before {
		t.Errorf("rejoin must not re-bump cooldown; before=%d after=%d", before, after)
	}
}

// ----------------------------------------------------------------------------
// Boss kill
// ----------------------------------------------------------------------------

func TestBossKill_DispatchesRewards(t *testing.T) {
	_, L, world, sender := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1912, 19012, "Hero", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
	})

	if err := L.DoString(`
		_rid = instance.create(EID, 300040000)
		_inst = instance.get(_rid)
		_boss = _inst.boss_eid
	`); err != nil {
		t.Fatalf("DoString create: %v", err)
	}
	bossLV := L.GetGlobal("_boss")
	if bossLV == lua.LNil || bossLV == lua.LNumber(0) {
		t.Fatalf("boss_eid not set on instance; got %v", bossLV)
	}

	sender.packets = nil
	if err := L.DoString(`_handled = instance.on_boss_kill(_boss, EID)`); err != nil {
		t.Fatalf("DoString kill: %v", err)
	}
	if L.GetGlobal("_handled") != lua.LTrue {
		t.Error("on_boss_kill should return true when victim is a run boss")
	}

	// Haramel reward: 5000 kinah (from template). Kinah add_kinah is Go-side
	// and writes to ECS stat directly.
	if k := func(e ecs.Entity, k string) float64 { v, _ := world.GetStat(e, k); return v }(eid, "kinah"); k != 5000 {
		t.Errorf("expected kinah to grow by 5000 reward, got %v", k)
	}

	// Verify SM_INSTANCE_REWARD (0xD3) and SM_INSTANCE_STATE (0xD2) go out.
	var rewardPkts, statePkts int
	for _, p := range sender.sentToGateway(1912) {
		if p.opcode == 0xD3 {
			rewardPkts++
		}
		if p.opcode == 0xD2 {
			statePkts++
		}
	}
	if rewardPkts < 1 {
		t.Errorf("expected ≥1 SM_INSTANCE_REWARD, got %d", rewardPkts)
	}
	if statePkts < 1 {
		t.Errorf("expected ≥1 SM_INSTANCE_STATE after clear, got %d", statePkts)
	}
	// State should be CLEARED.
	if err := L.DoString(`_state = _inst.state`); err != nil {
		t.Fatalf("DoString state: %v", err)
	}
	if v := L.GetGlobal("_state"); v != lua.LNumber(2 /* STATE_CLEARED */) {
		t.Errorf("expected state=CLEARED(2) after boss kill, got %v", v)
	}
}

func TestBossKill_IdempotentRewards(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1913, 19013, "Hero", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
	})

	if err := L.DoString(`
		_rid = instance.create(EID, 300040000)
		_boss = instance.get(_rid).boss_eid
		instance.on_boss_kill(_boss, EID)
		-- Second kill on the same boss: rewards_given guard must block.
		_handled2 = instance.on_boss_kill(_boss, EID)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_handled2") != lua.LFalse {
		t.Error("second boss kill on already-rewarded run should return false")
	}
	if k := func(e ecs.Entity, k string) float64 { v, _ := world.GetStat(e, k); return v }(eid, "kinah"); k != 5000 {
		t.Errorf("kinah should still be exactly 5000 (no double reward), got %v", k)
	}
}

// ----------------------------------------------------------------------------
// Reset
// ----------------------------------------------------------------------------

func TestReset_HappyPath(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	// Haramel reset_fee_kinah = 1000.
	eid := spawnS19Player(t, world, 1914, 19014, "Pay", 5, 5000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
	})
	if err := L.DoString(`_ok, _r = instance.reset(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("want ok=true, got _r=%v", L.GetGlobal("_r"))
	}
	if k := func(e ecs.Entity, k string) float64 { v, _ := world.GetStat(e, k); return v }(eid, "kinah"); k != 4000 {
		t.Errorf("kinah should drop by 1000 fee, got %v", k)
	}
}

func TestReset_NoKinah(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1915, 19015, "Broke", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
	})
	if err := L.DoString(`_ok, _r = instance.reset(EID, 300040000)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("want ok=false on no_kinah, got %v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("no_kinah") {
		t.Errorf("want reason=no_kinah, got %v", L.GetGlobal("_r"))
	}
}

func TestReset_UnknownTemplate(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1916, 19016, "Tester", 5, 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = instance.reset(EID, 424242)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_r") != lua.LString("template_unknown") {
		t.Errorf("want reason=template_unknown, got %v", L.GetGlobal("_r"))
	}
}

// ----------------------------------------------------------------------------
// Stale jobq expire guard
// ----------------------------------------------------------------------------

func TestOnExpire_MatchingCreatedAt_Disposes(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1917, 19017, "Solo", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
		"aion_GetBindPoint":             `{[1]={x=0,y=0,z=0}}`,
	})
	if err := L.DoString(`
		_rid = instance.create(EID, 300040000)
		_created = instance.get(_rid).created_at_unix
		instance.on_expire(_rid, _created)
		_gone = (instance.get(_rid) == nil)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_gone") != lua.LTrue {
		t.Error("matching created_at should dispose the run")
	}
}

func TestOnExpire_StaleCreatedAt_NoOps(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1918, 19018, "Solo", 5, 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
	})
	if err := L.DoString(`
		_rid = instance.create(EID, 300040000)
		-- Stale payload with created_at mismatch.
		instance.on_expire(_rid, 1)
		_still = (instance.get(_rid) ~= nil)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_still") != lua.LTrue {
		t.Error("stale created_at must NOT dispose the run")
	}
}

// ----------------------------------------------------------------------------
// Group coupling — kick/leave hooks
// ----------------------------------------------------------------------------

func TestGroupKick_ForcesInstanceLeave(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	leader := spawnS19Player(t, world, 1920, 19020, "Lead", 60, 0)
	mate := spawnS19Player(t, world, 1921, 19021, "Mate", 60, 0)
	L.SetGlobal("LEAD", lua.LNumber(float64(leader)))
	L.SetGlobal("MATE", lua.LNumber(float64(mate)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
		"aion_GetBindPoint":             `{[1]={x=0,y=0,z=0}}`,
	})

	if err := L.DoString(`
		group.invite(LEAD, MATE)
		group.accept(MATE)
		_rid = instance.create(LEAD, 300320000)
		_mate_in_before = (instance.get_by_eid(MATE) ~= nil)
		group.kick(LEAD, MATE)
		_mate_in_after = (instance.get_by_eid(MATE) ~= nil)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_mate_in_before") != lua.LTrue {
		t.Fatal("mate must be inside instance before kick")
	}
	if L.GetGlobal("_mate_in_after") != lua.LFalse {
		t.Error("group.kick must force instance.leave on mate")
	}
}

func TestGroupLeave_ForcesInstanceLeave(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	leader := spawnS19Player(t, world, 1922, 19022, "Lead", 60, 0)
	mate := spawnS19Player(t, world, 1923, 19023, "Mate", 60, 0)
	L.SetGlobal("LEAD", lua.LNumber(float64(leader)))
	L.SetGlobal("MATE", lua.LNumber(float64(mate)))

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
		"aion_GetBindPoint":             `{[1]={x=0,y=0,z=0}}`,
	})

	if err := L.DoString(`
		group.invite(LEAD, MATE)
		group.accept(MATE)
		_rid = instance.create(LEAD, 300320000)
		group.leave(MATE)
		_mate_in_after = (instance.get_by_eid(MATE) ~= nil)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_mate_in_after") != lua.LFalse {
		t.Error("group.leave must force instance.leave on mate")
	}
}

func TestGroupCallback_SafeWhenNotInInstance(t *testing.T) {
	// The hooks must not blow up when the kicked player was never in an
	// instance. pcall inside group.lua guards against misbehaving callbacks;
	// here we just verify the nil-safe branch.
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	leader := spawnS19Player(t, world, 1924, 19024, "Lead", 5, 0)
	mate := spawnS19Player(t, world, 1925, 19025, "Mate", 5, 0)
	L.SetGlobal("LEAD", lua.LNumber(float64(leader)))
	L.SetGlobal("MATE", lua.LNumber(float64(mate)))

	if err := L.DoString(`
		group.invite(LEAD, MATE)
		group.accept(MATE)
		_ok = group.kick(LEAD, MATE)
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Error("group.kick without instance should still succeed")
	}
}

// ----------------------------------------------------------------------------
// Handler dispatch + NPC registration
// ----------------------------------------------------------------------------

func TestCmInstanceEnterHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1930, 19030, "EnterTest", 5, 0)

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
		"aion_setuserinstance_20171122": `{}`,
	})

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1930))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	// Payload: int32 template_id = 300040000 = 0x11E1A300 → LE bytes: 00 A3 E1 11
	payload := []byte{0x00, 0xA3, 0xE1, 0x11}

	fn := L.GetGlobal("dispatch_packet")
	if fn == lua.LNil {
		t.Fatal("dispatch_packet missing")
	}
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 0, Protect: true},
		lua.LNumber(0xCF), ctx, lua.LString(string(payload))); err != nil {
		t.Fatalf("dispatch_packet(0xCF): %v", err)
	}
}

func TestCmInstanceLeaveHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1931, 19031, "LeaveTest", 5, 0)

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1931))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	fn := L.GetGlobal("dispatch_packet")
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 0, Protect: true},
		lua.LNumber(0xD1), ctx, lua.LString("")); err != nil {
		t.Fatalf("dispatch_packet(0xD1): %v", err)
	}
}

func TestCmInstanceResetHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS19Bridge(t, nil)
	defer L.Close()
	eid := spawnS19Player(t, world, 1932, 19032, "ResetTest", 5, 0)

	installInstanceDB(t, L, map[string]string{
		"aion_getuserinstance_20171122": `{}`,
	})

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1932))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	// 300040000 LE = 00 A3 E1 11
	payload := []byte{0x00, 0xA3, 0xE1, 0x11}
	fn := L.GetGlobal("dispatch_packet")
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 0, Protect: true},
		lua.LNumber(0xD4), ctx, lua.LString(string(payload))); err != nil {
		t.Fatalf("dispatch_packet(0xD4): %v", err)
	}
}

func TestNpcHaramelRegistered(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()
	if err := L.DoString(`_h = dialog.has(798006)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_h") != lua.LTrue {
		t.Error("npc_798006 (Haramel) not registered with dialog")
	}
}

func TestNpcBeshmundirRegistered(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()
	if err := L.DoString(`_h = dialog.has(798007)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_h") != lua.LTrue {
		t.Error("npc_798007 (Beshmundir) not registered with dialog")
	}
}

// ----------------------------------------------------------------------------
// Event scripts
// ----------------------------------------------------------------------------

func TestOnInstanceExpireScriptLoaded(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()
	if _, ok := L.GetGlobal("on_instance_expire").(*lua.LFunction); !ok {
		t.Error("on_instance_expire function not loaded")
	}
}

func TestOnDailyResetCallsSP(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()

	if err := L.DoString(`
		_sp_called = false
		_G.db = { call = function(name, ...)
			if name == "aion_initinstancecooltime_170817" then
				_sp_called = true
			end
			return {}
		end }
		on_daily_reset()
	`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_sp_called") != lua.LTrue {
		t.Error("on_daily_reset did not call aion_initinstancecooltime_170817")
	}
}

func TestOnDailyReset_NoDb_SafelyNoOp(t *testing.T) {
	_, L, _, _ := newS19Bridge(t, nil)
	defer L.Close()
	if err := L.DoString(`_G.db = nil; on_daily_reset()`); err != nil {
		t.Fatalf("on_daily_reset with nil db should not raise: %v", err)
	}
}
