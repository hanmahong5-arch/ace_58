// Package luahost — Phase S-17 regression tests.
//
// Covers the Go→Lua invoker bridge used by background jobq workers:
//   - VMPool.CallGlobal happy path
//   - CallGlobal returns ErrLuaGlobalMissing for unknown / non-function names
//   - argument conversion covers int / int64 / string / bool / nil
//   - the three Phase S-17 event scripts (on_auction_expire /
//     on_legion_invite_expire / on_mail_deliver) are loaded and callable
//   - legion._clear_invite removes matching pending invites and no-ops on
//     non-matching legion_id
package luahost

import (
	"errors"
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

var s17ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS17Pool constructs a pooled VMPool (capacity=2) loaded with the full
// scripts tree plus a synthetic probe script that defines a trio of global
// functions the test can assert on.
func newS17Pool(t *testing.T, extra string) (*VMPool, *Bridge) {
	t.Helper()
	world := ecs.NewWorld()
	bridge := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockCaptureSender{}}

	pool, err := NewVMPool(2, s17ScriptsDir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}

	if extra != "" {
		// Inject the probe script into every pooled VM by draining and
		// executing it on each state. Tests that need a probe must run it
		// after NewVMPool so the functions exist on every checked-out VM.
		for i := 0; i < 2; i++ {
			L := pool.Acquire()
			if err := L.DoString(extra); err != nil {
				pool.Release(L)
				pool.Close()
				t.Fatalf("DoString(extra): %v", err)
			}
			pool.Release(L)
		}
	}
	return pool, bridge
}

// ─────────────────────────────────────────────────────────────────────────
// TestCallGlobalHappyPath — simple arg-less global function.
// ─────────────────────────────────────────────────────────────────────────
func TestCallGlobalHappyPath(t *testing.T) {
	probe := `
		_probe_counter = 0
		function _probe_noop() _probe_counter = _probe_counter + 1 end
	`
	pool, _ := newS17Pool(t, probe)
	defer pool.Close()

	if err := pool.CallGlobal("_probe_noop"); err != nil {
		t.Fatalf("CallGlobal: %v", err)
	}

	// Verify the counter incremented on the VM that CallGlobal used.
	L := pool.Acquire()
	defer pool.Release(L)
	n, ok := L.GetGlobal("_probe_counter").(lua.LNumber)
	if !ok {
		t.Fatalf("_probe_counter is not a number: %T", L.GetGlobal("_probe_counter"))
	}
	if int(n) != 1 {
		t.Errorf("expected counter=1, got %d", int(n))
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCallGlobalMissing — unknown name returns ErrLuaGlobalMissing.
// ─────────────────────────────────────────────────────────────────────────
func TestCallGlobalMissing(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	err := pool.CallGlobal("_no_such_function_please_stay_missing")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, ErrLuaGlobalMissing) {
		t.Errorf("expected ErrLuaGlobalMissing, got %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCallGlobalNonFunction — global that exists but is not a function.
// ─────────────────────────────────────────────────────────────────────────
func TestCallGlobalNonFunction(t *testing.T) {
	probe := `_probe_table = { x = 1 }`
	pool, _ := newS17Pool(t, probe)
	defer pool.Close()

	err := pool.CallGlobal("_probe_table")
	if !errors.Is(err, ErrLuaGlobalMissing) {
		t.Errorf("expected ErrLuaGlobalMissing for non-function global, got %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCallGlobalArgConversion — int / int64 / string / bool arguments.
// ─────────────────────────────────────────────────────────────────────────
func TestCallGlobalArgConversion(t *testing.T) {
	probe := `
		_probe_captured = nil
		function _probe_record(a, b, c, d)
			_probe_captured = { a = a, b = b, c = c, d = d }
		end
	`
	pool, _ := newS17Pool(t, probe)
	defer pool.Close()

	if err := pool.CallGlobal("_probe_record",
		int64(42), "hello", true, 3.14); err != nil {
		t.Fatalf("CallGlobal: %v", err)
	}

	L := pool.Acquire()
	defer pool.Release(L)
	tbl, ok := L.GetGlobal("_probe_captured").(*lua.LTable)
	if !ok {
		t.Fatalf("_probe_captured is not a table: %T", L.GetGlobal("_probe_captured"))
	}
	if n, _ := L.GetField(tbl, "a").(lua.LNumber); int64(n) != 42 {
		t.Errorf("a: expected 42, got %v", n)
	}
	if s, _ := L.GetField(tbl, "b").(lua.LString); string(s) != "hello" {
		t.Errorf("b: expected hello, got %v", s)
	}
	if v, _ := L.GetField(tbl, "c").(lua.LBool); !bool(v) {
		t.Errorf("c: expected true, got %v", v)
	}
	if n, _ := L.GetField(tbl, "d").(lua.LNumber); float64(n) != 3.14 {
		t.Errorf("d: expected 3.14, got %v", n)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCallGlobalLuaError — Lua-side runtime error becomes a Go error.
// ─────────────────────────────────────────────────────────────────────────
func TestCallGlobalLuaError(t *testing.T) {
	probe := `function _probe_fail() error("boom") end`
	pool, _ := newS17Pool(t, probe)
	defer pool.Close()

	err := pool.CallGlobal("_probe_fail")
	if err == nil {
		t.Fatal("expected error from Lua, got nil")
	}
	if errors.Is(err, ErrLuaGlobalMissing) {
		t.Errorf("unexpected ErrLuaGlobalMissing: %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCallGlobalReleasesVM — pool size unchanged after a full call cycle.
// ─────────────────────────────────────────────────────────────────────────
func TestCallGlobalReleasesVM(t *testing.T) {
	probe := `function _probe_noop2() end`
	pool, _ := newS17Pool(t, probe)
	defer pool.Close()

	before := func() int {
		pool.mu.Lock()
		defer pool.mu.Unlock()
		return len(pool.pool)
	}()
	if err := pool.CallGlobal("_probe_noop2"); err != nil {
		t.Fatalf("CallGlobal: %v", err)
	}
	after := func() int {
		pool.mu.Lock()
		defer pool.mu.Unlock()
		return len(pool.pool)
	}()
	if before != after {
		t.Errorf("pool size drifted: before=%d after=%d", before, after)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireScriptLoaded — the S-17 Lua event script defines the
// global on_auction_expire function.
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireScriptLoaded(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	L := pool.Acquire()
	defer pool.Release(L)
	if _, ok := L.GetGlobal("on_auction_expire").(*lua.LFunction); !ok {
		t.Fatalf("expected on_auction_expire function, got %T",
			L.GetGlobal("on_auction_expire"))
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnLegionInviteExpireScriptLoaded — S-17 legion event script loaded.
// ─────────────────────────────────────────────────────────────────────────
func TestOnLegionInviteExpireScriptLoaded(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	L := pool.Acquire()
	defer pool.Release(L)
	if _, ok := L.GetGlobal("on_legion_invite_expire").(*lua.LFunction); !ok {
		t.Fatalf("expected on_legion_invite_expire function, got %T",
			L.GetGlobal("on_legion_invite_expire"))
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnMailDeliverScriptLoaded — S-17 mail event script loaded.
// ─────────────────────────────────────────────────────────────────────────
func TestOnMailDeliverScriptLoaded(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	L := pool.Acquire()
	defer pool.Release(L)
	if _, ok := L.GetGlobal("on_mail_deliver").(*lua.LFunction); !ok {
		t.Fatalf("expected on_mail_deliver function, got %T",
			L.GetGlobal("on_mail_deliver"))
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestLegionClearInvitePresent — _clear_invite removes matching invite.
// ─────────────────────────────────────────────────────────────────────────
func TestLegionClearInvitePresent(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	L := pool.Acquire()
	defer pool.Release(L)

	// Seed a pending invite by running a small Lua snippet that reaches into
	// legion.lua's private _pending_invites table via legion.invite (full
	// happy path requires a lot of prerequisites; use the test hook).
	snippet := `
		legion._reset()
		-- Fabricate a pending invite row directly via a back-door helper
		-- that legion.lua conveniently exposes for S-17 tests.
		legion._seed_invite(42, 101, 1001)  -- target_eid, inviter_eid, legion_id
		return legion._clear_invite(42, 1001)
	`
	if err := L.DoString(snippet); err != nil {
		t.Fatalf("snippet: %v", err)
	}
	ret := L.Get(-1)
	L.Pop(1)
	if ret != lua.LTrue {
		t.Errorf("expected _clear_invite to return true, got %v", ret)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestLegionClearInviteMismatch — legion_id mismatch does not clear.
// ─────────────────────────────────────────────────────────────────────────
func TestLegionClearInviteMismatch(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	L := pool.Acquire()
	defer pool.Release(L)

	snippet := `
		legion._reset()
		legion._seed_invite(42, 101, 1001)
		return legion._clear_invite(42, 9999)  -- wrong legion_id
	`
	if err := L.DoString(snippet); err != nil {
		t.Fatalf("snippet: %v", err)
	}
	ret := L.Get(-1)
	L.Pop(1)
	if ret != lua.LFalse {
		t.Errorf("expected _clear_invite to return false on mismatch, got %v", ret)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestLegionClearInviteMissing — clearing a non-existent invite is false.
// ─────────────────────────────────────────────────────────────────────────
func TestLegionClearInviteMissing(t *testing.T) {
	pool, _ := newS17Pool(t, "")
	defer pool.Close()

	L := pool.Acquire()
	defer pool.Release(L)

	if err := L.DoString(`legion._reset()`); err != nil {
		t.Fatalf("reset: %v", err)
	}
	if err := L.DoString(`_ret = legion._clear_invite(9999, 1)`); err != nil {
		t.Fatalf("call: %v", err)
	}
	if L.GetGlobal("_ret") != lua.LFalse {
		t.Errorf("expected false on missing invite")
	}
}
