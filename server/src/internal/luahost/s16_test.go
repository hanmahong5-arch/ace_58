// Package luahost — Phase S-16 regression tests.
//
// Covers the Auction House MVP (scripts/lib/auction.lua +
// handlers/cm_auction_{search,register,bid,cancel}.lua + npcs/npc_798005.lua)
// AND the jobq.enqueue delay extension wired into bridge.go in S-16:
//
//   - auction global with register/search/bid/cancel + the four constants
//     (MAX_ACTIVE_PER_USER, LISTING_FEE_RATE, MIN/MAX_DURATION_HOURS)
//   - register rejection matrix: bad_count, bad_bid, bad_duration,
//     too_many_listings, no_kinah, sp_failed → kinah rolled back
//   - register happy path: fee deducted, aion_InsertAuctionListing observed,
//     listing_id surfaced
//   - register schedules an "aion58.auction.expire" job with delay equal to
//     duration_hours * 3600 seconds (verifies bridge.EnqueueKindIn wiring)
//   - register survives Jobs=nil (Redis-disabled) by treating the disabled
//     enqueue as non-fatal — the listing is still persisted
//   - search empty (nil rows / empty SP) and search returning a 3-row table
//   - bid rejection matrix: bad_amount, not_found, own_listing, expired,
//     bid_too_low, sp_failed (kinah refunded)
//   - bid happy path: kinah escrow + aion_InsertAuctionBid observed
//   - cancel rejection matrix: not_owner, has_bids
//   - cancel happy path: aion_CancelAuction observed
//   - all four CM_AUCTION_* opcodes (0xC9/CA/CB/CC) dispatch without panic
//   - npc_798005 dialog registered
//   - jobq.enqueue with a delay arg routes through EnqueueKindIn (60s) and
//     without a delay routes through EnqueueKind (delay==0 on mock)
package luahost

import (
	"testing"
	"time"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// newS16Bridge wires a fresh ECS world + Bridge + Lua state with all scripts
// loaded. The optional jobs argument lets a test wire a mockJobQueue (or nil
// to keep the Redis-disabled degraded path).
func newS16Bridge(t *testing.T, jobs JobQueue) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender, Jobs: jobs}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s14ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s16 loadScripts: %v", err)
	}
	return b, L, world, sender
}

// spawnS16Player creates a player-controlled entity with the stats that
// auction.* reads (char_id, kinah, dead). Position defaults to origin since
// none of the auction flows take a range check.
func spawnS16Player(t *testing.T, world *ecs.World,
	gw uint64, charID float64, name string, kinah float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "kinah", kinah)
	world.SetStat(eid, "dead", 0)
	return eid
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionLibLoaded — auction global table exists with register/search/
// bid/cancel functions and the four documented constants.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionLibLoaded(t *testing.T) {
	_, L, _, _ := newS16Bridge(t, nil)
	defer L.Close()

	tbl, ok := L.GetGlobal("auction").(*lua.LTable)
	if !ok {
		t.Fatalf("expected auction to be a table, got %T", L.GetGlobal("auction"))
	}
	for _, fn := range []string{"register", "search", "bid", "cancel"} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected auction.%s to be a function, got %T",
				fn, L.GetField(tbl, fn))
		}
	}
	for _, c := range []string{
		"MAX_ACTIVE_PER_USER", "LISTING_FEE_RATE",
		"MIN_DURATION_HOURS", "MAX_DURATION_HOURS",
	} {
		if _, ok := L.GetField(tbl, c).(lua.LNumber); !ok {
			t.Errorf("expected auction.%s constant, got %T",
				c, L.GetField(tbl, c))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionConstants — exact constant values match the documented contract.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionConstants(t *testing.T) {
	_, L, _, _ := newS16Bridge(t, nil)
	defer L.Close()

	tbl := L.GetGlobal("auction").(*lua.LTable)
	if v := L.GetField(tbl, "MAX_ACTIVE_PER_USER"); v != lua.LNumber(15) {
		t.Errorf("MAX_ACTIVE_PER_USER: want 15, got %v", v)
	}
	if v := L.GetField(tbl, "MIN_DURATION_HOURS"); v != lua.LNumber(6) {
		t.Errorf("MIN_DURATION_HOURS: want 6, got %v", v)
	}
	if v := L.GetField(tbl, "MAX_DURATION_HOURS"); v != lua.LNumber(48) {
		t.Errorf("MAX_DURATION_HOURS: want 48, got %v", v)
	}
	// LISTING_FEE_RATE is a float; allow a small epsilon for representation.
	rate, ok := L.GetField(tbl, "LISTING_FEE_RATE").(lua.LNumber)
	if !ok {
		t.Fatalf("LISTING_FEE_RATE missing")
	}
	if d := float64(rate) - 0.02; d > 1e-9 || d < -1e-9 {
		t.Errorf("LISTING_FEE_RATE: want 0.02, got %v", rate)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterBadCount — item_id<=0 OR count<=0 yields false,"bad_count"
// and the seller's kinah is untouched.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterBadCount(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1600, 16001, "Bad", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// item_id=0 branch.
	if err := L.DoString(`_ok, _r = auction.register(EID, 0, 1, 100, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on item_id=0, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_count") {
		t.Errorf("want reason=bad_count on item_id=0, got %v", v)
	}

	// count=0 branch.
	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 0, 100, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on count=0, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_count") {
		t.Errorf("want reason=bad_count on count=0, got %v", v)
	}

	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must be untouched on bad_count, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterBadBid — min_bid<=0 and (buy_now>0 && buy_now<min_bid)
// both rejected as "bad_bid".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterBadBid(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1601, 16002, "BadBid", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// min_bid=0 → bad_bid.
	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 0, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse || L.GetGlobal("_r") != lua.LString("bad_bid") {
		t.Errorf("min_bid=0 branch: want false/bad_bid, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}

	// buy_now < min_bid → bad_bid.
	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 500, 100, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse || L.GetGlobal("_r") != lua.LString("bad_bid") {
		t.Errorf("buy_now<min_bid branch: want false/bad_bid, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}

	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on bad_bid, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterBadDuration — duration outside [MIN, MAX] is rejected
// without spending any kinah.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterBadDuration(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1602, 16003, "BadDur", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// duration=1 (< MIN=6).
	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 1)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("bad_duration") {
		t.Errorf("duration=1: want false/bad_duration, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}

	// duration=100 (> MAX=48).
	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 100)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("bad_duration") {
		t.Errorf("duration=100: want false/bad_duration, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}

	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on bad_duration, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterTooManyListings — programmableDB returns a count=15 row
// for aion_CountActiveAuctions; auction.register must reject before the fee
// is debited.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterTooManyListings(t *testing.T) {
	b, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1603, 16004, "Hoarder", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_CountActiveAuctions": {
				{"count": int64(15)},
			},
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("want ok=false, got %v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("too_many_listings") {
		t.Errorf("want reason=too_many_listings, got %v", L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must be untouched on too_many_listings, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterNoKinah — seller has 5 kinah but the listing fee on
// min_bid=1000 is ceil(1000*0.02)=20. spend_kinah fails → "no_kinah".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterNoKinah(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1604, 16005, "Broke", 5)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("want ok=false, got %v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("no_kinah") {
		t.Errorf("want reason=no_kinah, got %v", L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 5 {
		t.Errorf("kinah must stay at 5 on no_kinah, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterHappyPath — programmableDB returns a listing_id=42 row
// from aion_InsertAuctionListing; auction.register returns true,42, the fee
// (ceil(1000*0.02)=20) is debited, and the SP is observed in the call log.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterHappyPath(t *testing.T) {
	b, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1605, 16006, "Happy", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			// aion_CountActiveAuctions absent → empty rows → skip the cap check.
			"aion_InsertAuctionListing": {
				{"listing_id": int64(42)},
			},
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Fatalf("want ok=true, got %v (reason=%v)",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if L.GetGlobal("_r") != lua.LNumber(42) {
		t.Errorf("want listing_id=42, got %v", L.GetGlobal("_r"))
	}
	// Fee = ceil(1000 * 0.02) = 20 → 500 - 20 = 480.
	if k, _ := world.GetStat(eid, "kinah"); k != 480 {
		t.Errorf("kinah should drop to 480 (fee=20), got %v", k)
	}
	if !pdb.sawCall("aion_InsertAuctionListing") {
		t.Errorf("expected aion_InsertAuctionListing SP call, calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterSpFailRollsBack — happy precondition (count check passes)
// but aion_InsertAuctionListing errors out. auction.register must return
// false,"sp_failed" AND refund the listing fee.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterSpFailRollsBack(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1606, 16007, "Rollback", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Pure Lua-level _G.db override is enough here because we don't need to
	// observe the SP call from Go — we only need to surface an error string.
	installAuctionDB(t, L, map[string]string{
		"aion_InsertAuctionListing!err": "db_outage",
	})

	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("want ok=false on SP fail, got %v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("sp_failed") {
		t.Errorf("want reason=sp_failed, got %v", L.GetGlobal("_r"))
	}
	// Fee = 20; rollback restores to original 500.
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be refunded to 500 on sp_failed, got %v", k)
	}
}

// installAuctionDB is the s16 equivalent of installMailDB / installWarehouseDB:
// rewrite _G.db.call so it returns canned rows for select SP names. Suffixing
// the SP name with "!err" makes it surface a (nil, error) tuple instead.
func installAuctionDB(t *testing.T, L *lua.LState, responses map[string]string) {
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
		t.Fatalf("installAuctionDB DoString failed: %v\n%s", err, src)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterSchedulesExpiry — a successful register must enqueue a
// single "aion58.auction.expire" job whose delay equals duration_hours*3600
// seconds. Verifies the bridge's jobq.enqueue → EnqueueKindIn wiring.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterSchedulesExpiry(t *testing.T) {
	jq := &mockJobQueue{}
	b, L, world, _ := newS16Bridge(t, jq)
	defer L.Close()

	eid := spawnS16Player(t, world, 1607, 16008, "Scheduler", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_InsertAuctionListing": {
				{"listing_id": int64(101)},
			},
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Fatalf("want ok=true, got %v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}

	last, ok := jq.last()
	if !ok {
		t.Fatal("no job enqueued; expected one auction.expire entry")
	}
	if last.kind != "aion58.auction.expire" {
		t.Errorf("kind: want aion58.auction.expire, got %q", last.kind)
	}
	want := 6 * time.Hour
	if last.delay != want {
		t.Errorf("delay: want %v, got %v", want, last.delay)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionRegisterWithDisabledJobq — Bridge.Jobs=nil makes jobq.enqueue
// degrade to (false,"disabled"); auction.register must treat that as
// non-fatal and still return ok=true with the listing_id.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionRegisterWithDisabledJobq(t *testing.T) {
	b, L, world, _ := newS16Bridge(t, nil) // Jobs = nil
	defer L.Close()

	eid := spawnS16Player(t, world, 1608, 16009, "NoRedis", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_InsertAuctionListing": {
				{"listing_id": int64(7)},
			},
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = auction.register(EID, 100001, 1, 1000, 0, 6)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Fatalf("disabled jobq must NOT roll back register, got %v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if L.GetGlobal("_r") != lua.LNumber(7) {
		t.Errorf("listing_id: want 7, got %v", L.GetGlobal("_r"))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionSearchEmpty — both branches of the empty path:
//   1) _G.db = nil → degrades to {} without errors;
//   2) SP returns 0 rows → returns {} (length 0).
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionSearchEmpty(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1609, 16010, "Searcher", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Path 1: nil DB binding.
	if err := L.DoString(`_G.db = nil`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if err := L.DoString(`_rows = auction.search(EID, 0, 0, 0, 0); _n = #_rows`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(0) {
		t.Errorf("want empty result with db=nil, got count=%v", v)
	}

	// Path 2: SP returns 0 rows.
	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionSearch": `{}`,
	})
	if err := L.DoString(`_rows = auction.search(EID, 100001, 0, 9999, 0); _n = #_rows`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(0) {
		t.Errorf("want empty result with empty SP rows, got count=%v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionSearchReturnsRows — programmableDB returns 3 listing rows and
// auction.search surfaces all 3 with the listing_id field intact.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionSearchReturnsRows(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1610, 16011, "MultiSearch", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionSearch": `{
			[1]={listing_id=10, item_id=100001, min_bid=500},
			[2]={listing_id=11, item_id=100002, min_bid=750},
			[3]={listing_id=12, item_id=100003, min_bid=900}
		}`,
	})

	chunk := `
_rows = auction.search(EID, 0, 0, 0, 0)
_n   = #_rows
_id1 = _rows[1].listing_id
_id3 = _rows[3].listing_id
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(3) {
		t.Fatalf("want 3 rows, got %v", v)
	}
	if v := L.GetGlobal("_id1"); v != lua.LNumber(10) {
		t.Errorf("row1 listing_id: want 10, got %v", v)
	}
	if v := L.GetGlobal("_id3"); v != lua.LNumber(12) {
		t.Errorf("row3 listing_id: want 12, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidBadAmount — listing_id<=0 OR amount<=0 yields "bad_amount".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidBadAmount(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1611, 16012, "Bidder", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = auction.bid(EID, 0, 100)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("bad_amount") {
		t.Errorf("listing_id=0: want false/bad_amount, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}

	if err := L.DoString(`_ok, _r = auction.bid(EID, 1, 0)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("bad_amount") {
		t.Errorf("amount=0: want false/bad_amount, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on bad_amount, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidNotFound — aion_GetAuctionById returns no rows → "not_found".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidNotFound(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1612, 16013, "Ghost", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{}`,
	})

	if err := L.DoString(`_ok, _r = auction.bid(EID, 999, 100)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("not_found") {
		t.Errorf("want false/not_found, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on not_found, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidOwnListing — GetAuctionById returns a row with seller_char_id
// matching the buyer's own char_id → "own_listing".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidOwnListing(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1613, 16014, "OwnBid", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{[1]={
			seller_char_id=16014,
			min_bid=100, current_bid=0,
			expires_at=` + futureTimestamp() + `}}`,
	})

	if err := L.DoString(`_ok, _r = auction.bid(EID, 5, 200)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("own_listing") {
		t.Errorf("want false/own_listing, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on own_listing, got %v", k)
	}
}

// futureTimestamp returns a Lua integer literal far enough in the future
// (1 hour) that os.time() < expires_at on every test run.
func futureTimestamp() string {
	t := time.Now().Add(time.Hour).Unix()
	return intLit(t)
}

func intLit(v int64) string {
	const digits = "0123456789"
	if v == 0 {
		return "0"
	}
	neg := v < 0
	if neg {
		v = -v
	}
	var b [20]byte
	i := len(b)
	for v > 0 {
		i--
		b[i] = digits[v%10]
		v /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidExpired — row has expires_at in the past → "expired".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidExpired(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1614, 16015, "LateBid", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	past := intLit(time.Now().Unix() - 100)
	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{[1]={
			seller_char_id=99999,
			min_bid=100, current_bid=0,
			expires_at=` + past + `}}`,
	})

	if err := L.DoString(`_ok, _r = auction.bid(EID, 5, 200)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("expired") {
		t.Errorf("want false/expired, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on expired, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidTooLow — current_bid=100 → required=101; amount=50 rejected.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidTooLow(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1615, 16016, "Stingy", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{[1]={
			seller_char_id=99998,
			min_bid=100, current_bid=100,
			expires_at=` + futureTimestamp() + `}}`,
	})

	if err := L.DoString(`_ok, _r = auction.bid(EID, 5, 50)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("bid_too_low") {
		t.Errorf("want false/bid_too_low, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah untouched on bid_too_low, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidHappyPath — programmableDB serves the listing row AND records
// the aion_InsertAuctionBid SP call. Buyer has 500 kinah, bids 100 → kinah
// drops to 400 and the bid SP is observed.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidHappyPath(t *testing.T) {
	b, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1616, 16017, "Bidder", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_GetAuctionById": {
				{
					"seller_char_id": int64(99997),
					"min_bid":        int64(100),
					"current_bid":    int64(0),
					"expires_at":     time.Now().Add(time.Hour).Unix(),
				},
			},
			// aion_InsertAuctionBid → empty rows = success.
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = auction.bid(EID, 50, 100)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Fatalf("want ok=true, got %v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 400 {
		t.Errorf("kinah should drop to 400 (escrowed 100), got %v", k)
	}
	if !pdb.sawCall("aion_InsertAuctionBid") {
		t.Errorf("expected aion_InsertAuctionBid SP call, calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionBidSpFailRollsBack — listing fetch OK, but aion_InsertAuctionBid
// errors. Bid must return false,"sp_failed" AND refund the escrowed kinah.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionBidSpFailRollsBack(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1617, 16018, "Refunded", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{[1]={
			seller_char_id=99996,
			min_bid=100, current_bid=0,
			expires_at=` + futureTimestamp() + `}}`,
		"aion_InsertAuctionBid!err": "shard_down",
	})

	if err := L.DoString(`_ok, _r = auction.bid(EID, 51, 100)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("sp_failed") {
		t.Errorf("want false/sp_failed, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be refunded to 500 on sp_failed, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionCancelNotOwner — listing's seller_char_id does not match the
// caller's char_id → "not_owner".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionCancelNotOwner(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1618, 16019, "Stranger", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{[1]={seller_char_id=99995, current_bid=0}}`,
	})

	if err := L.DoString(`_ok, _r = auction.cancel(EID, 7)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("not_owner") {
		t.Errorf("want false/not_owner, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionCancelHasBids — owner matches but row.current_bid > 0 → "has_bids".
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionCancelHasBids(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1619, 16020, "TooLate", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installAuctionDB(t, L, map[string]string{
		"aion_GetAuctionById": `{[1]={seller_char_id=16020, current_bid=200}}`,
	})

	if err := L.DoString(`_ok, _r = auction.cancel(EID, 9)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LFalse || L.GetGlobal("_r") != lua.LString("has_bids") {
		t.Errorf("want false/has_bids, got %v/%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestAuctionCancelHappyPath — owner matches, no bids → true and the
// aion_CancelAuction SP is observed in the programmableDB call log.
// ─────────────────────────────────────────────────────────────────────────────
func TestAuctionCancelHappyPath(t *testing.T) {
	b, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1620, 16021, "OwnerOK", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_GetAuctionById": {
				{
					"seller_char_id": int64(16021),
					"current_bid":    int64(0),
				},
			},
			// aion_CancelAuction → empty rows = success.
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = auction.cancel(EID, 13)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Fatalf("want ok=true, got %v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
	if !pdb.sawCall("aion_CancelAuction") {
		t.Errorf("expected aion_CancelAuction SP call, calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmAuctionHandlersRegistered — dispatch_packet for all four CM_AUCTION_*
// opcodes (0xC9 search, 0xCA register, 0xCB bid, 0xCC cancel) executes
// without raising a Lua error. Most are rejected at the lib layer (missing
// rows / bad params) but that's expected — this test only checks wiring.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmAuctionHandlersRegistered(t *testing.T) {
	_, L, world, _ := newS16Bridge(t, nil)
	defer L.Close()

	eid := spawnS16Player(t, world, 1621, 16022, "Dispatcher", 1000)

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1621))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}

	// CM_AUCTION_SEARCH (0xC9): int32 + int64 + int64 + int32 = 24 bytes.
	searchPayload := make([]byte, 4+8+8+4)
	// CM_AUCTION_REGISTER (0xCA): int32 item_id + int32 count + int64 min_bid +
	// int64 buy_now + int32 duration_hours = 28 bytes. We craft a duration<MIN
	// so register rejects at bad_duration before touching the DB.
	regPayload := make([]byte, 4+4+8+8+4)
	// CM_AUCTION_BID (0xCB): int64 listing_id + int64 amount = 16 bytes.
	bidPayload := make([]byte, 16)
	// CM_AUCTION_CANCEL (0xCC): int64 listing_id = 8 bytes.
	cancelPayload := make([]byte, 8)

	for _, op := range []struct {
		opcode uint16
		body   []byte
	}{
		{0xC9, searchPayload},
		{0xCA, regPayload},
		{0xCB, bidPayload},
		{0xCC, cancelPayload},
	} {
		err := L.CallByParam(lua.P{
			Fn:      dispatchFn,
			NRet:    0,
			Protect: true,
		}, lua.LNumber(op.opcode), ctx, lua.LString(string(op.body)))
		if err != nil {
			t.Fatalf("dispatch_packet(0x%X) returned error: %v", op.opcode, err)
		}
	}

	// Sanity: bad_duration / bad_amount rejects must not have spent kinah.
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must stay at 1000 across reject path, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestNpc798005Registered — dialog.has(798005) is true after script load,
// confirming the Auction House Broker NPC script registered its dialog.
// ─────────────────────────────────────────────────────────────────────────────
func TestNpc798005Registered(t *testing.T) {
	_, L, _, _ := newS16Bridge(t, nil)
	defer L.Close()

	if err := L.DoString(`_has = dialog.has(798005)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if v := L.GetGlobal("_has"); v != lua.LTrue {
		t.Errorf("expected dialog.has(798005)==true, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueWithDelay — jobq.enqueue with a positive third arg routes
// through Bridge.Jobs.EnqueueKindIn; the mock records the duration verbatim.
// ─────────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueWithDelay(t *testing.T) {
	jq := &mockJobQueue{}
	_, L, _, _ := newS16Bridge(t, jq)
	defer L.Close()

	if err := L.DoString(`return jobq.enqueue("test.delayed", { x = 1 }, 60)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	last, ok := jq.last()
	if !ok {
		t.Fatal("no job recorded")
	}
	if last.kind != "test.delayed" {
		t.Errorf("kind: want test.delayed, got %q", last.kind)
	}
	if last.delay != 60*time.Second {
		t.Errorf("delay: want 60s, got %v", last.delay)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueImmediateNoDelay — jobq.enqueue without a third arg routes
// through EnqueueKind (mock records delay==0).
// ─────────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueImmediateNoDelay(t *testing.T) {
	jq := &mockJobQueue{}
	_, L, _, _ := newS16Bridge(t, jq)
	defer L.Close()

	if err := L.DoString(`return jobq.enqueue("test.now", {})`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	last, ok := jq.last()
	if !ok {
		t.Fatal("no job recorded")
	}
	if last.kind != "test.now" {
		t.Errorf("kind: want test.now, got %q", last.kind)
	}
	if last.delay != 0 {
		t.Errorf("delay: want 0, got %v", last.delay)
	}
}
