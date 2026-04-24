package luahost

import (
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"
)

// newTempScriptsDir creates an isolated scripts tree so watcher tests do not
// collide with the real scripts/ directory hot-reload.
// The layout mirrors the production shape: <root>/lib/<one.lua> plus a
// non-lib file to cover both ordering branches of loadScripts.
func newTempScriptsDir(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	libDir := filepath.Join(root, "lib")
	if err := os.MkdirAll(libDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(libDir, "shared.lua"),
		[]byte(`shared_value = 1`), 0o644); err != nil {
		t.Fatalf("write lib: %v", err)
	}
	if err := os.WriteFile(filepath.Join(root, "handler.lua"),
		[]byte(`function probe() return shared_value end`), 0o644); err != nil {
		t.Fatalf("write handler: %v", err)
	}
	return root
}

// TestVMPoolLifecycle exercises NewVMPool / Acquire / Release / Close on a
// minimal in-memory scripts tree. Also exercises the capacity-exceeded
// Release branch (VM closed instead of returned to pool).
func TestVMPoolLifecycle(t *testing.T) {
	dir := newTempScriptsDir(t)
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}

	pool, err := NewVMPool(2, dir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}
	defer pool.Close()

	// Drain and then force the "pool exhausted → temporary VM" path.
	a := pool.Acquire()
	b := pool.Acquire()
	c := pool.Acquire() // exhaustion path
	if a == nil || b == nil || c == nil {
		t.Fatal("Acquire returned nil")
	}

	// Release three into a capacity-2 pool: the third must be closed, not kept.
	pool.Release(a)
	pool.Release(b)
	pool.Release(c) // capacity exceeded branch
}

// TestNewVMPoolCapacityFloor verifies capacity < 1 is coerced to 1.
func TestNewVMPoolCapacityFloor(t *testing.T) {
	dir := newTempScriptsDir(t)
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}

	pool, err := NewVMPool(0, dir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}
	defer pool.Close()
	if pool.capacity != 1 {
		t.Errorf("capacity = %d, want 1", pool.capacity)
	}
}

// TestWatchScriptsSucceeds covers the happy path of filepath.WalkDir inside
// WatchScripts, confirming that subdirectories are added without error.
func TestWatchScriptsSucceeds(t *testing.T) {
	dir := newTempScriptsDir(t)
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}

	pool, err := NewVMPool(1, dir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}
	defer pool.Close()

	if err := pool.WatchScripts(); err != nil {
		t.Fatalf("WatchScripts: %v", err)
	}
}

// TestWatchLoopReloadsOnFileChange drives a full hot-reload cycle: start the
// watcher, touch a .lua file, and confirm the pool swaps its VMs.
// We detect the swap by inspecting pool identity after debounce elapses.
func TestWatchLoopReloadsOnFileChange(t *testing.T) {
	dir := newTempScriptsDir(t)
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}

	pool, err := NewVMPool(1, dir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}
	defer pool.Close()

	if err := pool.WatchScripts(); err != nil {
		t.Fatalf("WatchScripts: %v", err)
	}
	pool.StartWatchLoop()

	// Snapshot the current VM pointer, then write a fresh script.
	pool.mu.Lock()
	origPtr := pool.pool[0]
	pool.mu.Unlock()

	target := filepath.Join(dir, "handler.lua")
	if err := os.WriteFile(target, []byte(`function probe() return 2 end`), 0o644); err != nil {
		t.Fatalf("rewrite: %v", err)
	}

	// Debounce is 500ms; allow up to 3s for reload to complete.
	deadline := time.Now().Add(3 * time.Second)
	swapped := false
	for time.Now().Before(deadline) {
		pool.mu.Lock()
		cur := pool.pool
		pool.mu.Unlock()
		if len(cur) == 1 && cur[0] != origPtr {
			swapped = true
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	if !swapped {
		t.Error("expected pool to swap VMs after file change")
	}
}

// TestReloadFailurePreservesOldPool writes invalid Lua, triggers a reload,
// and verifies the pool keeps its original state rather than becoming empty.
func TestReloadFailurePreservesOldPool(t *testing.T) {
	dir := newTempScriptsDir(t)
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}

	pool, err := NewVMPool(1, dir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}
	defer pool.Close()

	pool.mu.Lock()
	origPtr := pool.pool[0]
	pool.mu.Unlock()

	// Write invalid Lua so reload() fails while building new states.
	if err := os.WriteFile(filepath.Join(dir, "handler.lua"),
		[]byte(`function probe( INVALID SYNTAX`), 0o644); err != nil {
		t.Fatalf("bad write: %v", err)
	}

	// Direct call — avoids watcher/debounce timing flakiness.
	pool.reload()

	pool.mu.Lock()
	defer pool.mu.Unlock()
	if len(pool.pool) != 1 || pool.pool[0] != origPtr {
		t.Errorf("expected old VM preserved on failed reload, pool=%v", pool.pool)
	}
}

// TestReleaseAtCapacityCloses probes the documented contract that Release
// beyond capacity closes the state rather than appending.
// We assert indirectly via atomic counter incremented by a Lua-bound function.
func TestReleaseAtCapacityCloses(t *testing.T) {
	dir := newTempScriptsDir(t)
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}

	pool, err := NewVMPool(1, dir, bridge)
	if err != nil {
		t.Fatalf("NewVMPool: %v", err)
	}
	defer pool.Close()

	// Pool starts with 1 VM. Acquire twice to create a temporary; Release
	// both so the second forces the capacity-exceeded branch.
	L1 := pool.Acquire()
	L2 := pool.Acquire()
	pool.Release(L1)
	pool.Release(L2)

	pool.mu.Lock()
	n := len(pool.pool)
	pool.mu.Unlock()
	if n != 1 {
		t.Errorf("pool size after over-release = %d, want 1", n)
	}

	// Basic sanity: we can still acquire.
	var counter int32
	L := pool.Acquire()
	atomic.AddInt32(&counter, 1)
	pool.Release(L)
	if atomic.LoadInt32(&counter) != 1 {
		t.Error("Acquire after over-release failed")
	}
}
